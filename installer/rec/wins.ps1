$ErrorActionPreference='Continue'
$g="$env:USERPROFILE\gtavi"
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class W {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
  public static List<string> List() {
    var res = new List<string>();
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      var sb = new StringBuilder(256); GetWindowTextW(h, sb, 256);
      var cn = new StringBuilder(256); GetClassNameW(h, cn, 256);
      RECT r; GetWindowRect(h, out r);
      res.Add(pid + "|" + IsWindowVisible(h) + "|" + cn + "|" + sb + "|" + r.l + "," + r.t + "," + r.r + "," + r.b);
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
'@
$gtapids = (Get-Process 'GTA VI' -ErrorAction SilentlyContinue).Id
$lines = [W]::List() | Where-Object { $p = ($_ -split '\|')[0]; $gtapids -contains [int]$p }
($lines -join "`n") | Set-Content "$g\wins.txt"
"pids: $($gtapids -join ',')" | Add-Content "$g\wins.txt"
