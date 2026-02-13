# 1. Проверка прав администратора
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 2. Установка приоритета в зависимости от прав
$proc = [System.Diagnostics.Process]::GetCurrentProcess()
try {
    if ($isAdmin) {
        $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
        Write-Host "Running as Admin: High Priority set." -ForegroundColor Green
    } else {
        $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::AboveNormal
        Write-Host "Running as User: AboveNormal Priority set." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not change priority."
}

# 3. Подключение WinApi
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

# Флаги для скорости (Async + NoActivate)
$SWP_FLAGS = 0x0001 -bor 0x0004 -bor 0x0010 -bor 0x4000
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

# Параметры физики
$gravity = 0.8
$friction = 0.98
$bounce = 0.7
$winStates = @{}
$cachedWindows = @()
$lastScan = 0

Write-Host "Physics engine started. Slingshot your windows!"

while($true) {
    # Кнопка Esc для выхода из скрипта
    if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }

    $isMouseDown = [WinApi]::GetAsyncKeyState(0x01) -ne 0
    $now = [Environment]::TickCount

    # Обновляем список окон раз в 2 секунды
    if ($now -gt $lastScan + 2000) {
        $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }
        $lastScan = $now
    }

    foreach ($p in $cachedWindows) {
        try {
            $hwnd = $p.MainWindowHandle
            if ($hwnd -eq [IntPtr]::Zero) { continue }

            $rect = New-Object WinApi+RECT
            if (-not [WinApi]::GetWindowRect($hwnd, [ref]$rect)) { continue }

            $id = $hwnd.ToString()
            if (-not $winStates.ContainsKey($id)) {
                $winStates[$id] = @{ vx=0; vy=0; oldX=$rect.Left; oldY=$rect.Top; isFlying=$false }
            }
            $state = $winStates[$id]

            # Логика рогатки (детектор броска)
            if ($rect.Left -ne $state.oldX -or $rect.Top -ne $state.oldY) {
                if ($isMouseDown) {
                    $state.vx = ($rect.Left - $state.oldX) * 2.0
                    $state.vy = ($rect.Top - $state.oldY) * 2.0
                    $state.isFlying = $true
                }
            }

            # Физика полета
            if ($state.isFlying -and -not $isMouseDown) {
                $state.vy += $gravity
                $state.vx *= $friction
                $state.vy *= $friction

                $w = $rect.Right - $rect.Left
                $h = $rect.Bottom - $rect.Top
                $nx = $rect.Left + $state.vx
                $ny = $rect.Top + $state.vy

                # Коллизии с границами экрана
                if ($nx -le 0) { $nx = 0; $state.vx *= -$bounce }
                if ($nx -ge ($workArea.Width - $w)) { $nx = $workArea.Width - $w; $state.vx *= -$bounce }
                if ($ny -le 0) { $ny = 0; $state.vy *= -$bounce }
                if ($ny -ge ($workArea.Height - $h)) { $ny = $workArea.Height - $h; $state.vy *= -$bounce }

                # Остановка
                if ([Math]::Abs($state.vx) -lt 0.5 -and [Math]::Abs($state.vy) -lt 1 -and $ny -ge ($workArea.Height - $h - 5)) {
                    $state.isFlying = $false
                }

                [WinApi]::SetWindowPos($hwnd, [IntPtr]::Zero, [int]$nx, [int]$ny, 0, 0, $SWP_FLAGS)
            }

            $state.oldX = $rect.Left
            $state.oldY = $rect.Top
        } catch { continue }
    }
    [System.Threading.Thread]::Sleep(1) # Максимальная частота обновления
}
