$ErrorActionPreference='Continue'
$g="$env:USERPROFILE\gtavi"
$desk="$env:USERPROFILE\Desktop"
$log="$g\record.log"
Remove-Item $log -Force -ErrorAction SilentlyContinue
function L($m){ "$((Get-Date).ToString('HH:mm:ss')) $m" | Add-Content $log }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Mus {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte b, byte s, uint f, UIntPtr e);
  [DllImport("shell32.dll")] public static extern void SHChangeNotify(int e, uint f, IntPtr a, IntPtr b);
}
'@

function Click($x, $y) {
  [Mus]::SetCursorPos($x, $y) | Out-Null
  Start-Sleep -Milliseconds 400
  [Mus]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
  [Mus]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
}

# show the desktop first
[Mus]::keybd_event(0x5B,0,0,[UIntPtr]::Zero); [Mus]::keybd_event(0x44,0,0,[UIntPtr]::Zero)
Start-Sleep -Milliseconds 150
[Mus]::keybd_event(0x44,0,2,[UIntPtr]::Zero); [Mus]::keybd_event(0x5B,0,2,[UIntPtr]::Zero)
Start-Sleep -Seconds 2
L "desktop shown"

$out = "$g\rec_raw.mp4"
Remove-Item $out -Force -ErrorAction SilentlyContinue
$ffp = Start-Process -FilePath "$g\bin\ffmpeg.exe" -ArgumentList @('-y','-f','gdigrab','-framerate','30','-i','desktop','-t','178','-c:v','libx264','-preset','veryfast','-pix_fmt','yuv420p',$out) -PassThru -WindowStyle Hidden
L "ffmpeg started pid=$($ffp.Id)"
Start-Sleep -Seconds 13

# step 1: open the installer from its desktop icon (second cell, right of the recycle bin)
L "opening installer"
Click 45 158
Start-Sleep -Milliseconds 600
[Mus]::keybd_event(0x0D,0,0,[UIntPtr]::Zero); [Mus]::keybd_event(0x0D,0,2,[UIntPtr]::Zero)
Start-Sleep -Seconds 4
if (-not (Get-Process 'GTA VI' -ErrorAction SilentlyContinue)) {
  L "fallback launch of installer"
  Start-Process "$g\GTA VI-win32-x64\GTA VI.exe"
}
Start-Sleep -Seconds 2
[Mus]::SetCursorPos(1300, 1100) | Out-Null
L "installer running"

$deadline = (Get-Date).AddSeconds(110)
while ((Get-Date) -lt $deadline) {
  if (-not (Get-Process 'GTA VI' -ErrorAction SilentlyContinue)) { break }
  Start-Sleep -Seconds 1
}
L "installer finished"
Start-Sleep -Seconds 2

# step 2: the setup icon becomes the game icon
Remove-Item "$desk\GTA VI Setup.lnk" -Force -ErrorAction SilentlyContinue
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut("$desk\GTA VI.lnk")
$s.TargetPath = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$s.Arguments = '--kiosk --user-data-dir="' + $env:TEMP + '\gtaviprof" --autoplay-policy=no-user-gesture-required --no-first-run --no-default-browser-check "file:///' + ($g -replace '\\','/') + '/play.html"'
$s.WorkingDirectory = $g
$s.IconLocation = "$g\GTA VI-win32-x64\GTA VI.exe,0"
$s.Description = 'Grand Theft Auto VI'
$s.Save()
[Mus]::SHChangeNotify(0x8000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
Start-Process ie4uinit.exe -ArgumentList '-show' -WindowStyle Hidden
Start-Sleep -Seconds 6
L "game shortcut created"

# step 3: launch it
Click 45 158
Start-Sleep -Milliseconds 600
[Mus]::keybd_event(0x0D,0,0,[UIntPtr]::Zero); [Mus]::keybd_event(0x0D,0,2,[UIntPtr]::Zero)
Start-Sleep -Seconds 5
if (-not (Get-Process 'chrome' -ErrorAction SilentlyContinue)) {
  L "fallback chrome kiosk"
  Start-Process 'C:\Program Files\Google\Chrome\Application\chrome.exe' -ArgumentList @('--kiosk', "--user-data-dir=$env:TEMP\gtaviprof", '--autoplay-policy=no-user-gesture-required', '--no-first-run', "file:///$(($g -replace '\\','/'))/play.html")
  Start-Sleep -Seconds 2
}
Get-Process 'GTA VI' -ErrorAction SilentlyContinue | Stop-Process -Force
[Mus]::SetCursorPos(2038, 1272) | Out-Null
L "gameplay running"

$ffp.WaitForExit()
L "ffmpeg exited"
