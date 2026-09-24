# Setup

## Requirements

- Windows 10 or Windows 11, 64-bit
- A Google Pixel running a current Android version (tested on Android 17)
- A data-capable USB cable
- Developer options and USB debugging enabled

The installer does not require administrative privileges.

## Keyboard layouts

While the scrcpy window is active, press left `Alt+K`. Android opens the physical keyboard settings for the scrcpy UHID keyboard. Add the layouts you use. Android commonly switches layouts with `Ctrl+Space`.

## Configuration

Run `pixel-on-pc.cmd configure` or edit `%LOCALAPPDATA%\PixelOnPC\config.json`. Valid starting DPI choices for a 14-inch 1080p screen are 180, 200 and 220.

## Uninstall

Run `%LOCALAPPDATA%\PixelOnPC\app\pixel-on-pc.cmd uninstall`. The uninstaller verifies an installation marker before removing files and shortcuts.
