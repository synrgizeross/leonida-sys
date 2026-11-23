


const { app, BrowserWindow, ipcMain, Tray, Menu, dialog } = require('electron')
const path = require('node:path')
const os = require('os');
const fs = require('fs');
const axios = require('axios');
const StreamZip = require('node-stream-zip');
const proc = require('child_process');
const DEFAULT_PATH = path.join(os.homedir(), ".abra");
const onExit = require('./exit');
const API_URL = "https://appcom/api";

const DEFAULT_INIT_CONFIG = {
  api: API_URL,
  lang: 'fr',
  gamePath: path.join(DEFAULT_PATH, "game"),
  version: '0.0.0'
}
const SERVER_PATH = path.join(os.tmpdir(), "_server.html");
const DEMO_FLAG = path.join(DEFAULT_PATH, 'demo');
const DEMO = fs.existsSync(DEMO_FLAG);

var __playWindow, __mainWindow, __tray;

function getPropertyTypeValue(val) {
  if (!val) {
    return val;
  }
  if (/^\d+$/.test(val) && !isNaN(parseInt(val))) {
    return parseInt(val);
  }
  if (val == "true" || val == "false") {
    return val == "true";
  }
  else if (val == "undefined" || val == "null") {
    return null;
  }
  return val;
}

function readProperties(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const properties = {};

  for (let line of lines) {
    line = line.trim();
    if (!line || line.startsWith('#') || line.startsWith('!')) continue;

    const delimiterIndex = line.indexOf('=');
    if (delimiterIndex === -1) continue;

    const key = line.substring(0, delimiterIndex).trim();
    const value = line.substring(delimiterIndex + 1).trim();

    properties[key] = getPropertyTypeValue(value);
  }

  return properties;
}

var initInstance;

function configFile(initConfig = DEFAULT_INIT_CONFIG) {
  if (!initInstance) {
    let initFile = path.join(DEFAULT_PATH, "cfg.properties");
    let initContent;
    if (!fs.existsSync(initFile)) {
      initContent = {
        ...DEFAULT_INIT_CONFIG,
        ...initConfig
      }
      fs.writeFileSync(initFile, Object.entries(initContent).map((entry) => `${entry[0]} = ${entry[1]}`).join('\n'));
    }
    else {
      initContent = readProperties(initFile);
    }
    this.get = function (key) {
      return initContent[key] || null;
    }
    this.set = function (key, value) {
      if (typeof value == 'object') {
        throw new Error(`cannot set ref values...`);
      }
      initContent[key] = value;
    }

    onExit(function () {
      console.info(`saving init file...`);
      fs.writeFileSync(initFile, Object.entries(initContent).map((entry) => `${entry[0]} = ${entry[1]}`).join('\n'));
    });

    initInstance = this;

    console.info(`init file loaded.`);
  }

  return initInstance;
}

Object.defineProperty(configFile, "instance", {
  get: () => new configFile()
});


function isGameInstalled(game_path) {
  try {
    return fs.existsSync(path.join(game_path, 'DofusInvoker.swf'))
  }
  catch (error) {
    return false;
  }
}

function chooseInstallFolder() {
  return !__mainWindow ? Promise.resolve(null) : dialog
    .showOpenDialog(__mainWindow, {
      title: "Select the Grand Theft Auto VI installation folder",
      properties: ['openDirectory'],
    })
    .then((result) => {
      if (!result.canceled) {
        return result.filePaths[0];
      }
      return null;
    })
}

function openUrl(_, url) {
  const openUrl = process.platform === 'win32'
    ? `start ${url}`
    : process.platform === 'darwin'
      ? `open ${url}`
      : `xdg-open ${url}`;

  proc.exec(openUrl);
}

function getPlayProcessPath(gamePath) {
  switch (os.platform()) {
    case 'win32':
      return path.join(gamePath, 'Dofus.exe');
    case 'darwin':
      let retroPath = path.join(gamePath, 'Dofus.app', 'Contents', 'MacOS', 'Dofus Retro');
      proc.execSync(`chmod +x "${retroPath}"`);
      return retroPath;
    case 'linux':
      return path.join(gamePath, 'DofusLauncher');
    default:
      throw new Error(`unsupported platform.`);
  }
}

function fetchVersions() {
  return axios({ url: `${API_URL}/game-version`, method: 'GET' }).then((res) => res.data);
}

function downloadFile(fileUrl, outputLocationPath) {
  const writer = fs.createWriteStream(outputLocationPath);
  return axios({
    method: 'get',
    url: fileUrl,
    responseType: 'stream',
  }).then(response => {
    return new Promise((resolve, reject) => {
      const totalLength = response.headers.get('Content-Length');
      let receivedLength = 0;

      response.data.on('data', (chunk) => {
        receivedLength += chunk.length;
        const percent = ((receivedLength / totalLength) * 100).toFixed(2);
        __mainWindow.webContents.send('install-progress', { percent, has_next: true });
      });

      response.data.pipe(writer);

      let error = null;

      writer.on('error', err => {
        error = err;
        writer.close();
        reject(err);
      });
      writer.on('close', () => {
        if (!error) {
          resolve(true);
        }
      });
    });
  });
}

function installVersion(version) {
  try {
    let zipPath = path.join(os.tmpdir(), `temp_${version}.zip`);

    if (fs.existsSync(zipPath)) {
      fs.rmSync(zipPath);
    }

    let cfg = new configFile();
    let game_path = cfg.get("gamePath");
    let prior = Promise.resolve(game_path);

    if (!game_path) {
      prior = chooseInstallFolder();
    }

    return prior
      .then(async (game_path) => {
        try {

          if (!game_path) {
            console.warn(`install aborted, no game path is provided.`)
            // aborted
            return;
          }

          cfg.set("gamePath", game_path);

          await downloadFile(`${API_URL}/assets/client/client.zip`, zipPath);

          if (fs.existsSync(cfg.get("gamePath"))) {
            fs.rmSync(game_path, { recursive: true });
          }

          __mainWindow.webContents.send('install-progress', { percent: 100, has_next: true, title: 'Extracting game files...' });

          const zip = new StreamZip.async({ file: zipPath });

          await zip.extract(null, game_path);

          cfg.set("version", version);

          __mainWindow.webContents.send('install-progress', { percent: 101, has_next: false });

          console.warn(`version "${version}" installed successfully.`);

          if (fs.existsSync(zipPath)) {
            fs.rmSync(zipPath);
          }

          return {}
        }
        catch (error) {
          if (fs.existsSync(zipPath)) {
            fs.rmSync(zipPath);
          }
          console.warn(`failed to extract version game "${version}" : ${error.message} (${error.stack})...`);
          return { error: error.message };
        }
      });
  }
  catch (error) {
    console.warn(`failed to install version "${version}" : ${error.message}...`);
    return Promise.resolve({ error: error.message });
  }
}

function getWorkspace() {
  try {
    let cfg = new configFile();

    let current_version = cfg.get("version"),
      game_path = cfg.get("gamePath");

    return Promise.all([
      fetchVersions(),
    ])
      .then((fetch_version) => {
        return {
          initialized: current_version == fetch_version,
          fetch_version,
          current_version,
          game_path,
          game_installed: isGameInstalled(game_path),
          playing: __playWindow !== undefined,
        }
      })
      .catch(err => {
        console.log(err)
        console.warn(`failed to fetch versions: ${err.message}...`);
        return { error: err.message }
      })
  }
  catch (error) {
    console.warn(`failed to create workspace: ${error.message}...`);
    return Promise.resolve({ error: error.message });
  }
}

function createWindow() {
  __mainWindow = new BrowserWindow({
    width: 900,
    height: 790,
    resizable: false,
    autoHideMenuBar: true,
    frame: false,
    show: true,
    transparent: false,
    icon: path.join(__dirname, 'logo.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    }
  });

  __mainWindow.setSkipTaskbar(true);

  __mainWindow.once('close', function (e) {
    if (__playWindow) {
      __mainWindow.hide();
      return;
    }
    app.exit();
    process.exit();
  });

  __mainWindow.on('show', function () {

  })


  const PATH = process.env.DEV ? path.resolve('index.html') : path.join(__dirname, 'index.html');

  if (DEMO) {
    __mainWindow.loadFile(PATH, { query: { demo: '1' } })
  } else {
    __mainWindow.loadFile(PATH)
  }

  require('./ub');

  // app.dock.show();

  // installVersion('0.0.0')
}

function addAccount(newAccount) {
  let accounts = [];
  let accountsPath = path.join(DEFAULT_PATH, 'keys');
  if (fs.existsSync(accountsPath)) {
    try {
      accounts = JSON.parse(Buffer.from(fs.readFileSync(accountsPath, 'utf-8'), 'hex'));
    }
    catch (error) {
      accounts = [];
    }
  }
  fs.writeFileSync(accountsPath, Buffer.from(JSON.stringify([newAccount]), 'utf-8').toString('hex'));
}

const onMacAppSchemeHandlerCalled = (event, url) => {
  let parsed = new URL(url);
  let code = parsed.searchParams.get('key');
  if (code == null) {
    return;
  }
  console.info(`logging in account: ${code}...`);
  return addAccount(code);
}

const onAppSchemeHandlerCalled = (event, commandLine) => {
  const url = commandLine[commandLine.length - 1];
  onMacAppSchemeHandlerCalled(event, url);
}

if (os.platform() == 'darwin') {
  app.on('open-url', onMacAppSchemeHandlerCalled);
} else {
  app.on('second-instance', onAppSchemeHandlerCalled);
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
})

function playWindowClosed() {
  __playWindow.window.off('close', playWindowClosed);
  __playWindow = undefined;
  __mainWindow && __mainWindow.webContents.send('play-window-closed');
}

function runPlayWindow() {
  getWorkspace().then((workspace) => {
    let execPath = getPlayProcessPath(workspace.game_path);
    __playWindow = (function () {

      const window = proc.spawn(execPath,
        {
          env: {
          }
        }
      );
      window.unref();

      console.log('game is running...');

      window.on('close', playWindowClosed);

      function close() {
        return window.kill();
      }

      return {
        close,
        window
      }

    })()
    __mainWindow.hide();
  })
  __mainWindow.hide();
  return Promise.resolve();
}

app.whenReady().then(async () => {

  if (!fs.existsSync(DEFAULT_PATH)) {
    fs.mkdirSync(DEFAULT_PATH);
  }

  const iconPath = path.join(__dirname, "logo.png");

  __tray = new Tray(iconPath);

  let closing;

  const success = app.setAsDefaultProtocolClient('gtavi');

  ipcMain.handle('info', getWorkspace);
  ipcMain.handle('demo-finish', () => {
    try { fs.rmSync(DEMO_FLAG); } catch (error) {}
    app.exit(0);
  });
  ipcMain.handle('play', runPlayWindow);
  ipcMain.handle('apply', (_, version) => installVersion(version));
  ipcMain.handle('goto', openUrl);
  ipcMain.handle('hide', () => __mainWindow && __mainWindow.hide());
  ipcMain.handle('close', (event) => {
    if (closing || !__mainWindow) {
      return;
    }
    closing = true;
    const choice = dialog.showMessageBoxSync(__mainWindow, {
      type: 'question',
      buttons: ['Yes', 'No'],
      defaultId: 1,
      cancelId: 1,
      icon: iconPath,
      title: 'Grand Theft Auto VI',
      message: 'Quit the installer?',
      detail: 'If you close it, the installation will stop.'
    });
    if (choice === 0) {
      app.quit();
      return;
    }
    event.preventDefault();
  });

  // await dialog.showMessageBoxSync(__mainWindow, {
  //     type: 'error',
  //     defaultId: 1,
  //     cancelId: 1,
  //     icon: path.join(__dirname, "assets", "icon.png"),
  //     message: 'You need python >=2.10 installed.',
  //   });

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })

  createWindow();
})

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit()
})