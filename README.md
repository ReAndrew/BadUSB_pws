# BadUSB_pws ⌨️⚡

An collection of optimized PowerShell one-liners and scripts specifically designed to be typed into the Windows **Run Window (Win+R)** via HID devices (BadUSB).

> [!WARNING]
> **Educational Purposes Only.** This tool is intended for security research and authorized penetration testing. Use it only on systems you own or have explicit permission to test. The author is not responsible for any misuse.

## Overview

The goal of this project is to provide highly compressed and efficient PowerShell commands that can be executed quickly through the Windows `Run` dialog. These scripts are tailored for HID attacks (Rubber Ducky, Flipper Zero, Digispark, etc.) where typing speed and payload length matter.

## Features

- **Short & Stealthy:** Payloads optimized to fit within the character limits of the Run window.
- **Bypass-Oriented:** Includes flags to bypass execution policies and hide windows.
- **Versatile:** Scripts for information gathering, reverse shells, and system tweaks.

## Typical Usage

To use these in your HID device, wrap the commands in DuckyScript or your device's native language.

**Standard Run Window Template:**
1. `GUI r` (Opens Run window)
2. `DELAY 500`
3. `STRING powershell -w h -NoP -Ep Bypass -c "YOUR_PAYLOAD_HERE"`
4. `ENTER`

## Payload Examples

| Payload | Description |
|---------|-------------|
| `Download & Execute` | Downloads a remote script and runs it in memory. |
| `Exfil WiFi` | Extracts saved WiFi passwords and sends them to a webhook. |
| `System Info` | Gathers hardware and OS details quickly. |
| `Reverse Shell` | Simple one-liner for a remote connection (use for testing). |

## Prerequisites

- Target OS: Windows 10/11
- HID-compatible device (e.g., Flipper Zero, Arduino Pro Micro, Rubber Ducky)
- Basic knowledge of PowerShell and DuckyScript

## Contributing

Contributions are welcome! If you have a clever one-liner or a new script:
1. Fork the repo.
2. Create your feature branch.
3. Submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
