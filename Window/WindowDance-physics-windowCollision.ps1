Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$code = @"
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Windows.Forms;
using System.Drawing;
using System.Linq;

public static class PhysicsEngine
{
    // --- WINAPI ---
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    // --- STATE ---
    private class WindowState {
        public IntPtr Hwnd;
        public float VX, VY;
        public int Width, Height;
        public int LastX, LastY;
        public bool IsBeingDragged; // <--- ВОТ ТВОЕ СПАСЕНИЕ
        public bool IsSleeping; 
    }

    private static float Gravity = 1.5f;   
    private static float Friction = 0.92f;  
    private static float Bounce = 0.5f;     
    
    private static ConcurrentDictionary<IntPtr, WindowState> _windows = new ConcurrentDictionary<IntPtr, WindowState>();
    private static bool _running = true;

    // ФЛАГИ: ASYNC | NOZORDER | NOACTIVATE | NOSIZE
    private const uint SWP_FLAGS = 0x4015; 

    public static void StartChaos()
    {
        SetProcessDPIAware(); 

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine(">>> PHYSICS ENGINE: DRAG & DROP UPGRADE <<<");
        Console.WriteLine(">>> HOLD 'END' TO EXIT <<<");
        Console.ResetColor();

        long lastScanTime = 0;
        Screen[] cachedScreens = Screen.AllScreens;

        while (_running)
        {
            if ((GetAsyncKeyState(0x23) & 0x8000) != 0) { _running = false; break; }

            long now = DateTime.Now.Ticks / 10000;
            if (now - lastScanTime > 1500) {
                ScanWindows();
                cachedScreens = Screen.AllScreens; 
                lastScanTime = now;
            }

            UpdatePhysicsParallel(cachedScreens); 
            
            Thread.Sleep(12); // ~80 FPS
        }
    }

    private static void ScanWindows()
    {
        Process[] procs = Process.GetProcesses();
        Parallel.ForEach(procs, p => {
            IntPtr h = p.MainWindowHandle;
            if (h == IntPtr.Zero) return;
            
            if (!_windows.ContainsKey(h)) {
                if (IsWindowVisible(h)) {
                    RECT r;
                    if (GetWindowRect(h, out r)) {
                        int w = r.Right - r.Left;
                        int h_val = r.Bottom - r.Top;
                        
                        if (w > 100 && h_val > 100) {
                            _windows.TryAdd(h, new WindowState {
                                Hwnd = h,
                                VX = 0, VY = 5.0f,
                                Width = w, Height = h_val,
                                LastX = r.Left, LastY = r.Top,
                                IsSleeping = false,
                                IsBeingDragged = false
                            });
                        }
                    }
                }
            }
        });
    }

    private static void UpdatePhysicsParallel(Screen[] screens)
    {
        bool isMouseDown = (GetAsyncKeyState(0x01) & 0x8000) != 0;
        
        Parallel.ForEach(_windows, kvp => {
            var s = kvp.Value;
            IntPtr hwnd = s.Hwnd;

            if (!IsWindow(hwnd)) { 
                WindowState dummy;
                _windows.TryRemove(hwnd, out dummy); 
                return; 
            }

            RECT r;
            if (!GetWindowRect(hwnd, out r)) return;

            int currentX = r.Left;
            int currentY = r.Top;

            // --- ЛОГИКА ЗАХВАТА ---
            if (isMouseDown) {
                // Если окно сдвинулось (значит юзер его потянул) ИЛИ оно уже было в захвате
                if (Math.Abs(currentX - s.LastX) > 5 || Math.Abs(currentY - s.LastY) > 5 || s.IsBeingDragged) {
                    
                    s.IsBeingDragged = true;  // ВКЛЮЧАЕМ РЕЖИМ ЗАХВАТА
                    s.IsSleeping = false;     // БУДИМ ЕГО

                    // Считаем скорость "броска" (инерция)
                    s.VX = (currentX - s.LastX) * 0.7f; 
                    s.VY = (currentY - s.LastY) * 0.7f;
                    
                    // Обновляем позицию и ВЫХОДИМ. НИКАКОЙ ГРАВИТАЦИИ.
                    s.LastX = currentX;
                    s.LastY = currentY;
                    return; 
                }
            } else {
                // Кнопку отпустили - выключаем захват
                s.IsBeingDragged = false;
            }

            // ЕСЛИ СПИТ - ПРОПУСКАЕМ
            if (s.IsSleeping) {
                s.LastX = currentX; s.LastY = currentY;
                return;
            }

            // --- ДАЛЬШЕ ИДЕТ ФИЗИКА (ТОЛЬКО ЕСЛИ НЕ ДЕРЖИШЬ РУКАМИ) ---
            
            int centerX = currentX + (s.Width / 2);
            int centerY = currentY + (s.Height / 2);
            
            Rectangle workArea = new Rectangle(0,0, 1920, 1080);
            bool foundScreen = false;
            foreach(var scr in screens) {
                if (scr.Bounds.Contains(centerX, centerY)) {
                    workArea = scr.WorkingArea;
                    foundScreen = true;
                    break;
                }
            }
            if (!foundScreen && screens.Length > 0) workArea = screens[0].WorkingArea;

            // Гравитация
            s.VY += Gravity;
            s.VX *= Friction;
            s.VY *= Friction;

            float newX = currentX + s.VX;
            float newY = currentY + s.VY;

            // Пол
            if (newY + s.Height >= workArea.Bottom) {
                newY = workArea.Bottom - s.Height;
                s.VY = -s.VY * Bounce;
            }
            // Потолок
            if (newY <= workArea.Top) {
                newY = workArea.Top;
                s.VY = -s.VY * 0.5f;
            }
            // Стены
            if (newX <= workArea.Left) {
                newX = workArea.Left;
                s.VX = -s.VX * Bounce;
            }
            if (newX + s.Width >= workArea.Right) {
                newX = workArea.Right - s.Width;
                s.VX = -s.VX * Bounce;
            }

            // Усыпление (оптимизация)
            if (Math.Abs(s.VX) < 0.2f && Math.Abs(s.VY) < 0.5f && (newY + s.Height >= workArea.Bottom - 5)) {
                s.IsSleeping = true;
                s.VX = 0; s.VY = 0;
            }

            if (!s.IsSleeping) {
                if ((int)newX != currentX || (int)newY != currentY) {
                    SetWindowPos(hwnd, IntPtr.Zero, (int)newX, (int)newY, 0, 0, SWP_FLAGS);
                    s.LastX = (int)newX;
                    s.LastY = (int)newY;
                }
            }
        });
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'PhysicsEngine').Type) {
    Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms, System.Drawing, System.Core
}

[PhysicsEngine]::StartChaos()
