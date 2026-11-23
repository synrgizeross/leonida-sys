$ErrorActionPreference='Continue'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Mu {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
}
'@
Start-Sleep -Seconds 1
[Mu]::SetCursorPos(45, 40) | Out-Null
Start-Sleep -Milliseconds 400
[Mu]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [Mu]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Milliseconds 150
[Mu]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [Mu]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Seconds 6
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$gr = [System.Drawing.Graphics]::FromImage($bmp)
$gr.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$bmp.Save("$env:USERPROFILE\gtavi\click_shot.png")
Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object ProcessName, MainWindowTitle | Format-Table -AutoSize | Out-File "$env:USERPROFILE\gtavi\click.log" -Encoding utf8
