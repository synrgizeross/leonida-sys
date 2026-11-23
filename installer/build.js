const esbuild = require("esbuild");
const path = require("path");
const fs = require('fs');
const archiver = require('archiver');
const packager = require('electron-packager');


// node build.js --name=Appix --icon="/path" --contentWeb="/path"

const args = process.argv.slice(2).reduce((a, b) => {
    const [key, ...value] = b.split('=');
    const propName = key.replace('--', '');
    a[propName] = value.join('=');
    return a;
}, {});


console.log(
    'running with: ',
    args
)


const { name, icon, contentWeb } = args;

if (!name) {
    console.warn('name required --name=""')
    process.exit();
}


if (!icon || !fs.existsSync(icon)) {
    console.warn('icon required --icon="" or maybe not found at ' + icon)
    process.exit();
}

if (contentWeb && !fs.existsSync(contentWeb)) {
    console.warn('contentWeb not found at: ' + contentWeb)
    process.exit();
}

const currentPackageContent = fs.readFileSync(path.join(__dirname, "package.json"), "utf-8");

async function copyLocalFiles(
    src,
    dest) {

    await fs.promises.mkdir(dest, { recursive: true });

    const entries = await fs.promises.readdir(src, { withFileTypes: true });

    for (let entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);

        if (entry.isDirectory()) {
            await copyLocalFiles(srcPath, destPath);
        } else {
            await fs.promises.copyFile(srcPath, destPath);
        }
    }
}

// Bundle main.js
Promise.all(

    [
        esbuild.build({
            external: ["electron"],
            entryPoints: [path.join(__dirname, "main.js")],
            bundle: true,
            platform: "node",     // Electron main runs in Node.js
            minify: true,
            outfile: path.join(__dirname, "build", "main.js"),
        }).catch(err => {
            console.error(err);
            process.exit()
        }),

        // Bundle preload.js
        esbuild.build({
            external: ["electron"],
            entryPoints: [path.join(__dirname, "preload.js")],
            bundle: true,
            platform: "node",     // preload also runs in Node context
            minify: true,
            outfile: path.join(__dirname, "build", "preload.js"),
        }).catch(err => {
            console.error(err);
            process.exit()
        }),
    ]
)
    .then(async () => {

        const build_path = path.join(__dirname, "build");


        fs.writeFileSync(path.join(build_path, "package.json"), currentPackageContent.replaceAll("DFPN", name))

        fs.cpSync(path.join(__dirname, "logo.png"), path.join(build_path, "logo.png"))
        fs.cpSync(icon, path.join(build_path, "logo.ico"))

        fs.cpSync(path.join(__dirname, "index.html"), path.join(build_path, "index.html"))
        fs.cpSync(path.join(__dirname, "assets"), path.join(build_path, "assets"), { recursive: true });


        if (contentWeb) {
            await copyLocalFiles(contentWeb, build_path);
        }

        const os = require('os');
        const [releasePath] = await packager({
            dir: build_path,
            name: name,
            out: path.join(__dirname, 'release'),
            arch: os.arch(),
            platform: os.platform(),
            asar: true,
            overwrite: true,
            prune: true,
            icon: icon,
        });


        const zipName = path.join(__dirname, 'release', `${name}-${os.platform()}-${os.arch()}.zip`);
        const output = fs.createWriteStream(zipName);
        const archive = archiver('zip', { zlib: { level: 9 } });

        output.on('close', () => {
            console.log(`ZIP created: ${zipName} (${archive.pointer()} bytes)`);
        });

        archive.on('error', err => { throw err; });

        archive.pipe(output);
        archive.directory(releasePath, false);

        await archive.finalize();

        console.log('Build complete:', releasePath);
    })
