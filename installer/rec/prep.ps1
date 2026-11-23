$ErrorActionPreference='Stop'
$g="$env:USERPROFILE\gtavi"
$desk="$env:USERPROFILE\Desktop"
$pub="C:\Users\Public\Desktop"
$log="$g\prep.log"
Remove-Item $log -Force -ErrorAction SilentlyContinue
function L($m){ "$((Get-Date).ToString('HH:mm:ss')) $m" | Add-Content $log }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int a, int b, string c, int d);
  [DllImport("user32.dll")] public static extern void keybd_event(byte b, byte s, uint f, UIntPtr e);
  [DllImport("shell32.dll")] public static extern IntPtr SHAppBarMessage(int m, ref APPBARDATA d);
  [DllImport("shell32.dll")] public static extern void SHChangeNotify(int e, uint f, IntPtr a, IntPtr b);
  [StructLayout(LayoutKind.Sequential)] public struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public int lParam; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
}
'@

# 1. remember current state (only on the first run)
if (-not (Test-Path "$g\state_wallpaper.txt")) {
  (Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper | Set-Content "$g\state_wallpaper.txt"
  "$((Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallpaperStyle),$((Get-ItemProperty 'HKCU:\Control Panel\Desktop').TileWallpaper)" | Set-Content "$g\state_wallstyle.txt"
  L "state saved"
} else { L "state already saved" }

# 2. show the desktop
[Win]::keybd_event(0x5B,0,0,[UIntPtr]::Zero); [Win]::keybd_event(0x44,0,0,[UIntPtr]::Zero)
Start-Sleep -Milliseconds 150
[Win]::keybd_event(0x44,0,2,[UIntPtr]::Zero); [Win]::keybd_event(0x5B,0,2,[UIntPtr]::Zero)
Start-Sleep -Seconds 1
L "desktop shown"

# 3. move every desktop item (user + public) into the backup folder
$bk="$env:USERPROFILE\Desktop_Backup_gta"
if (-not (Test-Path $bk)) { New-Item -ItemType Directory -Path $bk | Out-Null }
$rc1 = Start-Process robocopy -ArgumentList @("$desk", "$bk", '/E', '/MOVE', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -Wait -PassThru -WindowStyle Hidden
L "user desktop backed up (robocopy exit $($rc1.ExitCode))"
$bkpub = "$bk\Public"
New-Item -ItemType Directory -Path $bkpub -Force | Out-Null
Get-ChildItem $pub -Force | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
  Move-Item $_.FullName -Destination $bkpub -Force
}
L "public desktop backed up"

# anything robocopy could not move goes now
Get-ChildItem $desk -Force | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
  try { Move-Item $_.FullName -Destination $bk -Force -ErrorAction Stop; L "moved leftover $($_.Name)" }
  catch { L "leftover failed: $($_.Name) $($_.Exception.Message)" }
}

# 4. wallpaper
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
[Win]::SystemParametersInfo(20, 0, "$g\wall_gta.png", 3) | Out-Null
Start-Sleep -Seconds 1
L "wallpaper set"

# 5. hide the taskbar
$abd = New-Object 'Win+APPBARDATA'
$abd.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($abd)
$abd.lParam = 1
[Win]::SHAppBarMessage(10, [ref]$abd) | Out-Null
Start-Sleep -Seconds 1
L "taskbar autohide on"

# 6. the setup shortcut
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut("$desk\GTA VI Setup.lnk")
$s.TargetPath = "$g\GTA VI-win32-x64\GTA VI.exe"
$s.WorkingDirectory = "$g\GTA VI-win32-x64"
$s.IconLocation = "$g\GTA VI-win32-x64\GTA VI.exe,0"
$s.Description = 'Grand Theft Auto VI Setup'
$s.Save()
L "setup shortcut created"

# 7. arm demo mode for the installer
if (-not (Test-Path "$env:USERPROFILE\.abra")) { New-Item -ItemType Directory -Path "$env:USERPROFILE\.abra" | Out-Null }
Set-Content -Path "$env:USERPROFILE\.abra\demo" -Value '1'
L "demo mode armed"

# 7b. hide the shell icons that leak identity (user's files, Linux, network, libraries, control panel)
if (-not (Test-Path "$g\state_hideicons.reg")) {
  Start-Process reg -ArgumentList @('export','HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons',"$g\state_hideicons.reg",'/y') -Wait -WindowStyle Hidden
  L "hideicons state saved"
}
$hideGuids = @(
  '{59031a47-3f72-44a7-89c5-5595fe6b30ee}',
  '{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}',
  '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}',
  '{031E4825-7B94-4DC3-B131-E946B44C8DD5}',
  '{26EE0668-A00A-44D7-9371-BEB064C98683}',
  '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}'
)
foreach ($k in @('NewStartPanel','ClassicStartMenu')) {
  $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\$k"
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  foreach ($guid in $hideGuids) { Set-ItemProperty -Path $path -Name $guid -Value 1 -Type DWord -Force }
}
L "shell icons hidden"

# 8. refresh the desktop view
[Win]::SHChangeNotify(0x8000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
Start-Process ie4uinit.exe -ArgumentList '-show' -WindowStyle Hidden
Start-Sleep -Seconds 2
[Win]::keybd_event(0x74,0,0,[UIntPtr]::Zero); [Win]::keybd_event(0x74,0,2,[UIntPtr]::Zero)
Start-Sleep -Seconds 2
L "desktop refreshed"

# 8a2. taskbar autohide through the registry (survives explorer restart)
$sr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
if (-not (Test-Path "$g\state_stuckrects.bin")) {
  [System.IO.File]::WriteAllBytes("$g\state_stuckrects.bin", (Get-ItemProperty $sr).Settings)
  L "stuckrects state saved"
}
$st = (Get-ItemProperty $sr).Settings
$st[8] = $st[8] -bor 0x01
Set-ItemProperty $sr -Name Settings -Value $st -Type Binary
L "taskbar autohide written to registry"

# 8b. hide remaining identity leaks: hidden files off, OVGWORK hidden, explorer restarted
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
if (-not (Test-Path "$g\state_hiddenfiles.txt")) {
  "$((Get-ItemProperty $adv).Hidden)" | Set-Content "$g\state_hiddenfiles.txt"
  L "hiddenfiles state saved"
}
Set-ItemProperty $adv -Name Hidden -Value 2 -Type DWord
attrib +h "$desk\OVGWORK" 2>$null
Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
Start-Sleep -Seconds 4
L "explorer restarted"

# re-apply taskbar autohide (explorer restart resets it)
$abd2 = New-Object 'Win+APPBARDATA'
$abd2.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($abd2)
$abd2.lParam = 1
[Win]::SHAppBarMessage(10, [ref]$abd2) | Out-Null
Start-Sleep -Seconds 1
L "taskbar autohide re-applied"

# dump what the desktop actually draws
try {
  Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
  $r = [System.Windows.Automation.AutomationElement]::RootElement
  $c = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'SysListView32')
  $lv = $r.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $c)
  if ($lv) {
    $names = @()
    foreach ($it in $lv.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)) {
      $br = $it.Current.BoundingRectangle
      $names += "$($it.Current.Name) @ $([int]$br.X),$([int]$br.Y) $([int]$br.Width)x$([int]$br.Height)"
    }
    $names | Set-Content "$g\icons.txt"
    L "icons: $($names -join ' | ')"
  } else { L "SysListView32 not found" }
} catch { L "uia failed: $($_.Exception.Message)" }

# 8c. warm up the kiosk chrome profile so the first real launch is clean
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*gtaviprof*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item "$env:TEMP\gtaviprof" -Recurse -Force -ErrorAction SilentlyContinue
Start-Process 'C:\Program Files\Google\Chrome\Application\chrome.exe' -ArgumentList @('--kiosk', "--user-data-dir=$env:TEMP\gtaviprof", '--autoplay-policy=no-user-gesture-required', '--no-first-run', '--no-default-browser-check', "file:///$(($g -replace '\\','/'))/play.html")
Start-Sleep -Seconds 7
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*gtaviprof*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
L "kiosk profile warmed"

# 9. reference screenshot
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$gr = [System.Drawing.Graphics]::FromImage($bmp)
$gr.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$bmp.Save("$g\prep_shot.png")
L "screenshot saved $($b.Width)x$($b.Height)"
L "done"
