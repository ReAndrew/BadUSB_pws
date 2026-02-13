# Импорт функции для управления окнами
$code = @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
}
"@
Add-Type -TypeDefinition $code

# Константы для SetWindowPos (не менять размер, не менять Z-порядок)
$SWP_NOSIZE = 0x0001
$SWP_NOZORDER = 0x0004

$amplitude = 100 # Высота волны в пикселях
$frequency = 0.1 # Скорость/частота волны
$t = 0

while($true) {
    # Получаем все процессы, у которых есть заголовок окна
    $processes = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }
    
    foreach ($p in $processes) {
        $hwnd = $p.MainWindowHandle
        
        # Рассчитываем новую позицию Y по синусоиде
        # Чтобы окна не слиплись, добавим смещение на основе ID процесса
        $yOffset = [Math]::Sin($t + $p.Id) * $amplitude
        $newY = 400 + $yOffset
        
        # Двигаем окно (X оставляем старым или тоже анимируем)
        # В данном примере X плавно ползет вправо
        $newX = ($t * 10 + ($p.Id % 500)) % 1500
        
        [WinApi]::SetWindowPos($hwnd, [IntPtr]::Zero, [int]$newX, [int]$newY, 0, 0, ($SWP_NOSIZE -bor $SWP_NOZORDER))
    }
    
    $t += $frequency
    Start-Sleep -Milliseconds 10 # Задержка для плавности
}
