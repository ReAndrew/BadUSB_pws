# Приоритеты и права
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$proc = [System.Diagnostics.Process]::GetCurrentProcess()
try { $proc.PriorityClass = if($isAdmin){"High"}else{"AboveNormal"} } catch{}

Add-Type -AssemblyName System.Windows.Forms
$code = @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -TypeDefinition $code

$SWP_FLAGS = 0x0001 -bor 0x0004 -bor 0x0010 -bor 0x4000
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$cx = $screen.Width / 2
$cy = $screen.Height / 2
$radius = [Math]::Min($screen.Width, $screen.Height) / 3

$angleOffset = 0
$lastScan = 0
$cachedWindows = @()

while($true) {
    if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
    $now = [Environment]::TickCount

    if ($now -gt $lastScan + 2000) {
        $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }
        $lastScan = $now
    }

    $count = $cachedWindows.Count
    if ($count -gt 0) {
        for ($i = 0; $i -lt $count; $i++) {
            try {
                $hwnd = $cachedWindows[$i].MainWindowHandle
                if ($hwnd -eq 0) { continue }

                $angle = ($i / $count) * [Math]::PI * 2 + $angleOffset
                $nx = $cx + [Math]::Cos($angle) * $radius - 200
                $ny = $cy + [Math]::Sin($angle) * $radius - 150

                [WinApi]::SetWindowPos($hwnd, 0, [int]$nx, [int]$ny, 0, 0, $SWP_FLAGS)
            } catch { continue }
        }
    }
    $angleOffset += 0.04
    [System.Threading.Thread]::Sleep(10)
}
