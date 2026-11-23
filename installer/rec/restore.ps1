$ErrorActionPreference='Stop'
$g="$env:USERPROFILE\gtavi"
$desk="$env:USERPROFILE\Desktop"
$log="$g\restore.log"
Remove-Item $log -Force -ErrorAction SilentlyContinue
function L($m){ "$((Get-Date).ToString('HH:mm:ss')) $m" | Add-Content $log }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win2 {
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int a, int b, string c, int d);
  [DllImport("shell32.dll")] public static extern IntPtr SHAppBarMessage(int m, ref APPDATA d);
  [StructLayout(LayoutKind.Sequential)] public struct APPDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public int lParam; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
}
'@

# close the recording players first
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*gtaviprof*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process 'GTA VI' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
L "players closed"

# put every desktop item back
$bk="$env:USERPROFILE\Desktop_Backup_gta"
if (Test-Path $bk) {
  $rc = Start-Process robocopy -ArgumentList @("$bk\Public", 'C:\Users\Public\Desktop', '/E', '/MOVE', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -Wait -PassThru -WindowStyle Hidden
  L "public desktop restored (robocopy exit $($rc.ExitCode))"
  $rc = Start-Process robocopy -ArgumentList @($bk, $desk, '/E', '/MOVE', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -Wait -PassThru -WindowStyle Hidden
  L "desktop restored (robocopy exit $($rc.ExitCode))"
  Remove-Item $bk -Force -Recurse -ErrorAction SilentlyContinue
} else { L "no backup folder" }

# drop the shortcuts we made
Remove-Item "$desk\GTA VI.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$desk\GTA VI Setup.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$desk\Public" -Force -Recurse -ErrorAction SilentlyContinue

# shell icons back
if (Test-Path "$g\state_hideicons.reg") {
  Start-Process reg -ArgumentList @('import',"$g\state_hideicons.reg") -Wait -WindowStyle Hidden
  L "shell icons restored"
}
attrib -h "$env:USERPROFILE\Desktop\OVGWORK" 2>$null
if (Test-Path "$g\state_hiddenfiles.txt") {
  $hv = ((Get-Content "$g\state_hiddenfiles.txt" -Raw).Trim())
  if ($hv) { Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name Hidden -Value ([int]$hv) -Type DWord }
}

# wallpaper back
$old = (Get-Content "$g\state_wallpaper.txt" -Raw).Trim()
$style = ((Get-Content "$g\state_wallstyle.txt" -Raw).Trim() -split ',')
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value $style[0]
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value $style[1]
if ($old -and (Test-Path $old)) { [Win2]::SystemParametersInfo(20, 0, $old, 3) | Out-Null } else { [Win2]::SystemParametersInfo(20, 0, '', 3) | Out-Null }
L "wallpaper restored: $old"

# taskbar back
$abd = New-Object 'Win2+APPDATA'
$abd.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($abd)
$abd.lParam = 0
[Win2]::SHAppBarMessage(10, [ref]$abd) | Out-Null
$sr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
if (Test-Path "$g\state_stuckrects.bin") {
  $orig = [System.IO.File]::ReadAllBytes("$g\state_stuckrects.bin")
  Set-ItemProperty $sr -Name Settings -Value $orig -Type Binary
  L "taskbar registry restored"
}
Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
Start-Sleep -Seconds 2
L "taskbar autohide off"

Remove-Item "$env:USERPROFILE\.abra\demo" -Force -ErrorAction SilentlyContinue
L "done"
