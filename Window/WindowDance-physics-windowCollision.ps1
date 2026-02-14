# --- 1. C# ЯДРО: БЫСТРЫЙ АНАЛИЗ И WINAPI ---
$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace WindowPhysics {
    public static class Utils {
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
        [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
        
        [StructLayout(LayoutKind.Sequential)] 
        public struct RECT { public int Left, Top, Right, Bottom; }

        // Метод расчета массы: Размер + Энтропия цвета (насколько "шумное" окно)
        public static float CalculateMass(Bitmap bmp, int samplesX, int samplesY) {
            if (bmp == null) return 10f;
            int w = bmp.Width; int h = bmp.Height;
            
            // Прямой доступ к памяти изображения (в 100 раз быстрее GetPixel)
            BitmapData bData = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int bytes = Math.Abs(bData.Stride) * h;
            byte[] rgbValues = new byte[bytes];
            Marshal.Copy(bData.Scan0, rgbValues, 0, bytes);
            bmp.UnlockBits(bData);

            long totalDiff = 0;
            int stepX = Math.Max(1, w / samplesX);
            int stepY = Math.Max(1, h / samplesY);
            int count = 0;

            // Проход по сетке пикселей
            for (int x = stepX; x < w; x += stepX) {
                for (int y = 0; y < h; y += stepY) {
                    int idx = (y * bData.Stride) + (x * 4);
                    int prevIdx = (y * bData.Stride) + ((x - stepX) * 4);
                    
                    // Сумма разницы цветов (B+G+R) между соседними точками
                    totalDiff += Math.Abs(rgbValues[idx] - rgbValues[prevIdx]) +       
                                 Math.Abs(rgbValues[idx + 1] - rgbValues[prevIdx + 1]) + 
                                 Math.Abs(rgbValues[idx + 2] - rgbValues[prevIdx + 2]);
                    count++;
                }
            }
            
            // Формула веса: Площадь + (Разнообразие цветов * коэффициент)
            float areaMass = (float)(w * h) / 10000f; 
            float diversityMass = count > 0 ? (float)totalDiff / count : 0;
            
            return Math.Max(10.0f, areaMass + (diversityMass * 3.0f)); 
        }
    }
}
'@

# Компиляция (защита от повторной загрузки)
if (-not ([System.Management.Automation.PSTypeName]'WindowPhysics.Utils').Type) {
    Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing, System.Windows.Forms
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# --- 2. НАСТРОЙКИ ФИЗИКИ ---
$gravity = 0.8          # Гравитация
$friction = 0.98        # Трение воздуха
$wallBounce = 0.7       # Упругость стен
$windowBounce = 0.85    # Упругость окон друг об друга
$winStates = @{}        # Хранилище данных окон
$SWP_FLAGS = 0x0001 -bor 0x0004 -bor 0x0010 -bor 0x4000 # ASYNCWINDOWPOS (чтобы не висло)
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea # Учитываем панель задач
$lastScan = 0

# Переменные для диагностики
$frameCount = 0
$lastDebugTime = [Environment]::TickCount
$perfScan = 0
$perfPhysics = 0
$perfCollision = 0

# --- 3. ФУНКЦИЯ ПОЛУЧЕНИЯ ДАННЫХ ---
function Get-WindowData($hwnd) {
    $rect = New-Object WindowPhysics.Utils+RECT
    [void][WindowPhysics.Utils]::GetWindowRect($hwnd, [ref]$rect)
    $w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
    
    # Игнорируем слишком мелкие объекты
    if ($w -le 50 -or $h -le 50) { return $null }
    
    try {
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
        $g.Dispose()
        
        # Расчет массы через C#
        $mass = [WindowPhysics.Utils]::CalculateMass($bmp, 50, 50)
        $bmp.Dispose()
        return @{ mass = $mass; w = $w; h = $h; rect = $rect }
    } catch {
        return @{ mass = 50; w = $w; h = $h; rect = $rect }
    }
}

Clear-Host
Write-Host "Physics Engine Started." -ForegroundColor Cyan
Write-Host "Press ESC to exit." -ForegroundColor Gray

# --- 4. ГЛАВНЫЙ ЦИКЛ ---
while($true) {
    # Выход
    if ([WindowPhysics.Utils]::GetAsyncKeyState(0x1B) -ne 0) { break }
    
    # Состояние мыши
    $isMouseDown = [WindowPhysics.Utils]::GetAsyncKeyState(0x01) -ne 0
    
    # --- СКАНИРОВАНИЕ ОКОН (Тайминг T1) ---
    $t1 = [Environment]::TickCount
    if ([Environment]::TickCount -gt $lastScan + 2000) { 
        $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }
        $lastScan = [Environment]::TickCount 
    }
    $activeIds = @()
    $perfScan = [Environment]::TickCount - $t1

    # --- ФИЗИКА (Тайминг T2) ---
    $t2 = [Environment]::TickCount
    foreach ($p in $cachedWindows) {
        try {
            $hwnd = $p.MainWindowHandle; if ($hwnd -eq 0) { continue }
            $id = $hwnd.ToString()
            
            # Получаем координаты
            $rect = New-Object WindowPhysics.Utils+RECT
            [void][WindowPhysics.Utils]::GetWindowRect($hwnd, [ref]$rect)
            $w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
            if ($w -lt 50 -or $h -lt 50) { continue }
            $activeIds += $id

            # Регистрация нового окна
            if (-not $winStates.ContainsKey($id)) { 
                $data = Get-WindowData $hwnd
                if ($data) {
                    # Получаем заголовок окна для отображения
                    $title = $p.MainWindowTitle
                    if ([string]::IsNullOrEmpty($title)) { $title = $p.ProcessName }
                    
                    $winStates[$id] = @{ 
                        title=$title;
                        vx=0; vy=0; oldX=$rect.Left; oldY=$rect.Top; 
                        isFlying=$false; mass=$data.mass; w=$data.w; h=$data.h 
                    }
                } else { continue }
            }
            $state = $winStates[$id]; $state.w = $w; $state.h = $h

            # Перетаскивание мышкой
            if ($rect.Left -ne $state.oldX -or $rect.Top -ne $state.oldY) { 
                if ($isMouseDown) { 
                    $state.vx = ($rect.Left - $state.oldX) * 2.2; $state.vy = ($rect.Top - $state.oldY) * 2.2; $state.isFlying = $true 
                } 
            }

            # Расчет полета
            if ($state.isFlying -and -not $isMouseDown) {
                $state.vy += $gravity; $state.vx *= $friction; $state.vy *= $friction
                $nx = $rect.Left + $state.vx; $ny = $rect.Top + $state.vy

                # Столкновения со стенами
                if ($nx -le 0 -or $nx -ge ($workArea.Width - $w)) { 
                    $state.vx *= -$wallBounce; $nx = [Math]::Max(0, [Math]::Min($nx, $workArea.Width - $w)) 
                }
                if ($ny -le 0 -or $ny -ge ($workArea.Height - $h)) { 
                    $state.vy *= -$wallBounce; $ny = [Math]::Max(0, [Math]::Min($ny, $workArea.Height - $h)) 
                }
                
                # Остановка
                if ([Math]::Abs($state.vx) -lt 0.5 -and [Math]::Abs($state.vy) -lt 1 -and $ny -ge ($workArea.Height - $h - 10)) { 
                    $state.isFlying = $false 
                }
                
                [void][WindowPhysics.Utils]::SetWindowPos($hwnd, 0, [int]$nx, [int]$ny, 0, 0, $SWP_FLAGS)
                $state.oldX = [int]$nx; $state.oldY = [int]$ny
            } else { $state.oldX = $rect.Left; $state.oldY = $rect.Top }
        } catch { continue }
    }
    $perfPhysics = [Environment]::TickCount - $t2

    # --- СТОЛКНОВЕНИЯ ОКОН (Тайминг T3) ---
    $t3 = [Environment]::TickCount
    for ($i = 0; $i -lt $activeIds.Count; $i++) {
        for ($j = $i + 1; $j -lt $activeIds.Count; $j++) {
            $sA = $winStates[$activeIds[$i]]; $sB = $winStates[$activeIds[$j]]
            if (-not $sA -or -not $sB) { continue }
            
            # Проверка пересечения (AABB)
            if ($sA.oldX -lt ($sB.oldX + $sB.w) -and ($sA.oldX + $sA.w) -gt $sB.oldX -and 
                $sA.oldY -lt ($sB.oldY + $sB.h) -and ($sA.oldY + $sA.h) -gt $sB.oldY) {
                
                $m1 = $sA.mass; $m2 = $sB.mass
                
                # Формула упругого удара
                $newVxA = ($sA.vx * ($m1 - $m2) + (2 * $m2 * $sB.vx)) / ($m1 + $m2)
                $newVyA = ($sA.vy * ($m1 - $m2) + (2 * $m2 * $sB.vy)) / ($m1 + $m2)
                $newVxB = ($sB.vx * ($m2 - $m1) + (2 * $m1 * $sA.vx)) / ($m1 + $m2)
                $newVyB = ($sB.vy * ($m2 - $m1) + (2 * $m1 * $sA.vy)) / ($m1 + $m2)
                
                $sA.vx = $newVxA * $windowBounce; $sA.vy = $newVyA * $windowBounce
                $sB.vx = $newVxB * $windowBounce; $sB.vy = $newVyB * $windowBounce
                $sA.isFlying = $true; $sB.isFlying = $true
                
                # Анти-залипание (раздвигаем окна)
                if ($sA.oldX -lt $sB.oldX) { $sA.oldX -= 4; $sB.oldX += 4 } else { $sA.oldX += 4; $sB.oldX -= 4 }
                if ($sA.oldY -lt $sB.oldY) { $sA.oldY -= 4; $sB.oldY += 4 } else { $sA.oldY += 4; $sB.oldY -= 4 }
            }
        }
    }
    $perfCollision = [Environment]::TickCount - $t3

    # --- ВЫВОД В КОНСОЛЬ (1 раз в сек) ---
    $frameCount++
    if ([Environment]::TickCount -gt $lastDebugTime + 1000) {
        $fps = $frameCount
        $frameCount = 0
        $lastDebugTime = [Environment]::TickCount
        
        Clear-Host
        Write-Host "=== PHYSICS ENGINE MONITOR ===" -ForegroundColor Yellow
        Write-Host "FPS: $fps" -ForegroundColor Cyan
        Write-Host "Timings: Scan(${perfScan}ms) | Physics(${perfPhysics}ms) | Collision(${perfCollision}ms)" -ForegroundColor Gray
        
        Write-Host "`n=== HEAVY WINDOWS (Sorted by Mass) ===" -ForegroundColor Yellow
        Write-Host "WINDOW NAME              | MASS   | STATUS " -ForegroundColor DarkGray
        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
        
        # Сортировка и вывод
        $sortedWindows = $winStates.Values | Sort-Object -Property mass -Descending | Select-Object -First 15
        foreach ($w in $sortedWindows) {
            # Обрезаем длинные названия
            $displayTitle = $w.title
            if ($displayTitle.Length -gt 23) { $displayTitle = $displayTitle.Substring(0, 20) + "..." }
            
            $status = if ($w.isFlying) { "FLYING" } else { "STATIC" }
            $massStr = "{0:N0}" -f $w.mass
            
            # Цветовая кодировка веса
            $color = if ($w.mass -gt 200) { "Red" } elseif ($w.mass -lt 50) { "Green" } else { "White" }
            
            Write-Host ("{0,-24} | {1,-6} | {2}" -f $displayTitle, $massStr, $status) -ForegroundColor $color
        }
        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
        Write-Host "Total Windows: $($winStates.Count)"
    }

    [System.Threading.Thread]::Sleep(10) # 100 FPS cap
}