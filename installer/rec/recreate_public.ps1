$ErrorActionPreference='Stop'
$pub = "C:\Users\Public\Desktop"
$ws = New-Object -ComObject WScript.Shell
$items = @(
  @{ Name = 'OBS Studio'; Target = 'C:\Program Files\obs-studio\bin\64bit\obs64.exe'; Dir = 'C:\Program Files\obs-studio\bin\64bit' },
  @{ Name = 'Oracle VirtualBox'; Target = 'C:\Program Files\Oracle\VirtualBox\VirtualBox.exe'; Dir = 'C:\Program Files\Oracle\VirtualBox' },
  @{ Name = 'TeamViewer'; Target = 'C:\Program Files\TeamViewer\TeamViewer.exe'; Dir = 'C:\Program Files\TeamViewer' },
  @{ Name = 'JPEXS Free Flash Decompiler'; Target = 'C:\Program Files (x86)\FFDec\ffdec.exe'; Dir = 'C:\Program Files (x86)\FFDec' },
  @{ Name = 'TouchEmuAdm'; Target = ($env:LOCALAPPDATA + '\Programs\TouchEmuAdm\TouchEmuAdm.exe'); Dir = ($env:LOCALAPPDATA + '\Programs\TouchEmuAdm') },
  @{ Name = 'Vision'; Target = 'C:\Program Files\Vision\Vision.exe'; Dir = 'C:\Program Files\Vision' }
)
foreach ($i in $items) {
  if (Test-Path $i.Target) {
    $s = $ws.CreateShortcut("$pub\$($i.Name).lnk")
    $s.TargetPath = $i.Target
    $s.WorkingDirectory = $i.Dir
    $s.IconLocation = "$($i.Target),0"
    $s.Save()
  }
}
Get-ChildItem $pub -Force | Select-Object Name
