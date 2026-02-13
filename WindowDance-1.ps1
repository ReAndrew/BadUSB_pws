$code = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WindowManager {
    // Импорт функций Win32 API
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public static List<IntPtr> GetVisibleWindows() {
        List<IntPtr> windows = new List<IntPtr>();
        EnumWindows(delegate (IntPtr hWnd, IntPtr lParam) {
            if (IsWindowVisible(hWnd) && GetWindowTextLength(hWnd) > 0) {
                windows.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return windows;
    }
}
"@

Add-Type -TypeDefinition $code


$allWindows = [WindowManager]::GetVisibleWindows()

$x = 0
$y = 0
$step = 40 # Смещение для каждого следующего окна

foreach ($hwnd in $allWindows) {
    
    [WindowManager]::MoveWindow($hwnd, $x, $y, 800, 600, $true)
    
    $x += $step
    $y += $step
    
    
    if ($x -gt 1000) { $x = 0; $y = 0 }
}

Write-Host "Готово! Все окна (всего: $($allWindows.Count)) были перемещены."
