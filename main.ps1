# --- НАСТРОЙКИ МЕНЮ ---
# Просто добавь новый элемент в этот массив, чтобы расширить меню
$MenuItems = @(
    [PSCustomObject]@{ Title = "CAPS_DANCE";            Action = { CapsLock-Dance } }
    [PSCustomObject]@{ Title = "WindowDance_Physics";   Action = { WinDance_Physics } }
    [PSCustomObject]@{ Title = "WindowDance_Circle";    Action = { WinDance_Circle } }
    [PSCustomObject]@{ Title = "WindowDance_Sinus";     Action = { WinDance_Sinus } }
)

# --- БЛОКИ КОДА (ФУНКЦИИ) ---
# Здесь ты прописываешь логику для каждого пункта
function CapsLock-Dance {

}

function Clean-TempFiles {
   #iem / iex
}

function Windows-Dance {}
function SNDTag-m {}

# --- ЛОГИКА ОТОБРАЖЕНИЯ ---
function Show-Menu {
    param (
        [string]$Header = "ГЛАВНОЕ МЕНЮ"
    )

    while ($true) {
        Clear-Host
        Write-Host "================ $Header ================" -ForegroundColor Magenta
        
        # Вывод пунктов с индексами
        for ($i = 0; $i -lt $MenuItems.Count; $i++) {
            Write-Host ("[{0}] {1}" -f ($i + 1), $MenuItems[$i].Title)
        }
        
        Write-Host "=========================================="
        $choice = Read-Host "Выберите пункт (1-$($MenuItems.Count))"

        # Проверка ввода
        if ($choice -as [int] -and $choice -ge 1 -and $choice -le $MenuItems.Count) {
            $index = [int]$choice - 1
            Write-Host "`nЗапуск: $($MenuItems[$index].Title)...`n" -ForegroundColor Gray
            
            # Выполнение кода, привязанного к пункту
            & $MenuItems[$index].Action
            
            Write-Host "`nНажмите любую клавишу, чтобы вернуться..."
            $null = [Console]::ReadKey()
        }
        else {
            Write-Host "Ошибка: Неверный выбор, попробуйте снова." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

# Запуск
Show-Menu
