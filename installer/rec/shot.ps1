$ErrorActionPreference='Stop'
$g="$env:USERPROFILE\gtavi"
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
$gr=[System.Drawing.Graphics]::FromImage($bmp)
$gr.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size)
$bmp.Save("$g\shot_task.png")
"OK $($b.Width)x$($b.Height) session=$((Get-Process -Id $PID).SessionId)" | Set-Content "$g\shot.log"