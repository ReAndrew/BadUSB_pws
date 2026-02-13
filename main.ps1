param (
    [string]$mode = "physics" # По умолчанию включаем физику
)

# --- БЛОК УПРАВЛЕНИЯ ПРОЦЕССАМИ ---
# Устанавливаем тег текущего процесса, чтобы его можно было найти
$currentTag = "WindowDance_Instance"
$host.ui.RawUI.WindowTitle = $currentTag

# Функция остановки всех копий
function Stop-AllDances {
    Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { 
        $_.MainWindowTitle -eq $currentTag -and $_.Id -ne $PID 
    } | Stop-Process -Force
}

# Если выбран режим остановки - просто убиваем процессы и выходим
if ($mode -eq "stop") {
    Stop-AllDances
    exit
}

# Перед запуском нового режима останавливаем старые
Stop-AllDances

# --- ПОДГОТОВКА (ПРИОРИТЕТЫ И API) ---
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
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

$SWP_FLAGS = 0x0001 -bor 0x0004 -bor 0x0010 -bor 0x4000
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$lastScan = 0
$cachedWindows = @()

# --- ЛОГИКА РЕЖИМОВ ---

if ($mode -eq "physics") {
    $gravity = 0.8; $friction = 0.98; $bounce = 0.7; $winStates = @{}
    while($true) {
        if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
        $isMouseDown = [WinApi]::GetAsyncKeyState(0x01) -ne 0
        if ([Environment]::TickCount -gt $lastScan + 2000) {
            $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }; $lastScan = [Environment]::TickCount
        }
        foreach ($p in $cachedWindows) {
            try {
                $hwnd = $p.MainWindowHandle; if ($hwnd -eq 0) { continue }
                $rect = New-Object WinApi+RECT; [void][WinApi]::GetWindowRect($hwnd, [ref]$rect)
                $id = $hwnd.ToString()
                if (-not $winStates.ContainsKey($id)) { $winStates[$id] = @{ vx=0; vy=0; oldX=$rect.Left; oldY=$rect.Top; isFlying=$false } }
                $state = $winStates[$id]
                if ($rect.Left -ne $state.oldX -or $rect.Top -ne $state.oldY) {
                    if ($isMouseDown) { $state.vx = ($rect.Left - $state.oldX) * 2.2; $state.vy = ($rect.Top - $state.oldY) * 2.2; $state.isFlying = $true }
                }
                if ($state.isFlying -and -not $isMouseDown) {
                    $state.vy += $gravity; $state.vx *= $friction; $state.vy *= $friction
                    $nx = $rect.Left + $state.vx; $ny = $rect.Top + $state.vy
                    $w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
                    if ($nx -le 0 -or $nx -ge ($workArea.Width - $w)) { $state.vx *= -$bounce; $nx = [Math]::Max(0, [Math]::Min($nx, $workArea.Width - $w)) }
                    if ($ny -le 0 -or $ny -ge ($workArea.Height - $h)) { $state.vy *= -$bounce; $ny = [Math]::Max(0, [Math]::Min($ny, $workArea.Height - $h)) }
                    if ([Math]::Abs($state.vx) -lt 0.5 -and [Math]::Abs($state.vy) -lt 1 -and $ny -ge ($workArea.Height - $h - 10)) { $state.isFlying = $false }
                    [void][WinApi]::SetWindowPos($hwnd, 0, [int]$nx, [int]$ny, 0, 0, $SWP_FLAGS)
                }
                $state.oldX = $rect.Left; $state.oldY = $rect.Top
            } catch {continue}
        }
        [System.Threading.Thread]::Sleep(5)
    }
}

elseif ($mode -eq "circle") {
    $angleOffset = 0; $cx = $workArea.Width / 2; $cy = $workArea.Height / 2; $radius = [Math]::Min($workArea.Width, $workArea.Height) / 3
    while($true) {
        if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
        if ([Environment]::TickCount -gt $lastScan + 2000) {
            $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }; $lastScan = [Environment]::TickCount
        }
        $count = $cachedWindows.Count
        for ($i = 0; $i -lt $count; $i++) {
            try {
                $hwnd = $cachedWindows[$i].MainWindowHandle; if ($hwnd -eq 0) { continue }
                $angle = ($i / $count) * [Math]::PI * 2 + $angleOffset
                $nx = $cx + [Math]::Cos($angle) * $radius - 200; $ny = $cy + [Math]::Sin($angle) * $radius - 150
                [void][WinApi]::SetWindowPos($hwnd, 0, [int]$nx, [int]$ny, 0, 0, $SWP_FLAGS)
            } catch {continue}
        }
        $angleOffset += 0.04; [System.Threading.Thread]::Sleep(10)
    }
}

elseif ($mode -eq "sinus") {
    $t = 0; $jumpH = $workArea.Height / 3
    while($true) {
        if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
        if ([Environment]::TickCount -gt $lastScan + 2000) {
            $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }; $lastScan = [Environment]::TickCount
        }
        foreach ($p in $cachedWindows) {
            try {
                $hwnd = $p.MainWindowHandle; if ($hwnd -eq 0) { continue }
                $phase = $p.Id * 0.1; $factor = [Math]::Pow([Math]::Abs([Math]::Sin($t + $phase)), 1.3)
                $nx = ($p.Id * 150) % ($workArea.Width - 400); $ny = ($workArea.Height - 350) - ($factor * $jumpH)
                [void][WinApi]::SetWindowPos($hwnd, 0, [int]$nx, [int]$ny, 0, 0, $SWP_FLAGS)
            } catch {continue}
        }
        $t += 0.08; [System.Threading.Thread]::Sleep(10)
    }
}
