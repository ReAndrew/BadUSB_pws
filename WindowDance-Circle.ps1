# Подключаем библиотеку для работы с формами (нужна для координат экрана)
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$centerX = $screen.Width / 2
$centerY = $screen.Height / 2
$radius = [Math]::Min($screen.Width, $screen.Height) / 3 # Радиус — треть от размера экрана

# Импорт WinApi для движения окон
$code = @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
}
"@
Add-Type -TypeDefinition $code

$SWP_NOSIZE = 0x0001
$SWP_NOZORDER = 0x0004
$angleOffset = 0 # Начальный угол вращения

while($true) {
    # Берем процессы с окнами, исключая сам рабочий стол и пустые заголовки
    $processes = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne "" }
    $count = $processes.Count

    if ($count -gt 0) {
        for ($i = 0; $i -lt $count; $i++) {
            $hwnd = $processes[$i].MainWindowHandle
            
            # Вычисляем угол для конкретного окна (равномерно по кругу)
            $angle = ($i / $count) * [Math]::PI * 2 + $angleOffset
            
            # Координаты X и Y
            $newX = $centerX + [Math]::Cos($angle) * $radius - 200 # -200 чтобы центр окна был в точке
            $newY = $centerY + [Math]::Sin($angle) * $radius - 150 # -150 коррекция высоты
            
            [WinApi]::SetWindowPos($hwnd, [IntPtr]::Zero, [int]$newX, [int]$newY, 0, 0, ($SWP_NOSIZE -bor $SWP_NOZORDER))
        }
    }
    
    $angleOffset += 0.05 # Скорость вращения круга
    Start-Sleep -Milliseconds 20
}
