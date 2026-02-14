$gravity = 0.8; $friction = 0.98; $bounce = 0.7; $winStates = @{}
    while($true) {
        if ([WinApi]::GetAsyncKeyState(0x1B) -ne 0) { break }
        $isMouseDown = [WinApi]::GetAsyncKeyState(0x01) -ne 0
        if ([Environment]::TickCount -gt $lastScan + 2000) { $cachedWindows = [System.Diagnostics.Process]::GetProcesses() | Where-Object { $_.MainWindowHandle -ne 0 }; $lastScan = [Environment]::TickCount }
        foreach ($p in $cachedWindows) {
            try {
                $hwnd = $p.MainWindowHandle; if ($hwnd -eq 0) { continue }
                $rect = New-Object WinApi+RECT; [void][WinApi]::GetWindowRect($hwnd, [ref]$rect)
                $id = $hwnd.ToString()
                if (-not $winStates.ContainsKey($id)) { $winStates[$id] = @{ vx=0; vy=0; oldX=$rect.Left; oldY=$rect.Top; isFlying=$false } }
                $state = $winStates[$id]
                if ($rect.Left -ne $state.oldX -or $rect.Top -ne $state.oldY) { if ($isMouseDown) { $state.vx = ($rect.Left - $state.oldX) * 2.2; $state.vy = ($rect.Top - $state.oldY) * 2.2; $state.isFlying = $true } }
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
