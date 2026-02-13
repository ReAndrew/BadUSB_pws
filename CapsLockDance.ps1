$wsh = New-Object -ComObject WScript.Shell
$count = 10 # Сколько раз мигнуть
$delay = 200
if ($count != -1) {
  for ($i = 0; $i -lt $count; $i++) {
    $wsh.SendKeys('{CAPSLOCK}')
    $wsh.SendKeys('{NUMLOCK}')
    $wsh.SendKeys('{SCROLLLOCK}')
    Start-Sleep -Milliseconds $delay
} }
if ($count == -1) {
  $wsh.SendKeys('{CAPSLOCK}')
  $wsh.SendKeys('{NUMLOCK}')
  $wsh.SendKeys('{SCROLLLOCK}')
  Start-Sleep -Milliseconds $delay
}
