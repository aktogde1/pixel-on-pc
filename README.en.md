# Pixel on PC

Use a Google Pixel as a separate Android workspace on a Windows PC over USB. Pixel on PC installs the official [Genymobile scrcpy](https://github.com/Genymobile/scrcpy), creates a 1080p virtual Android display, connects the PC keyboard and mouse, forwards audio, and turns the phone OLED off while you work.

Tested on a Pixel 9 Pro XL with GrapheneOS based on Android 17 and Windows 11.

> [!IMPORTANT]
> This is an independent community project. It is not affiliated with or endorsed by GrapheneOS, Google, or Genymobile.

## Install

The first public release will support this one-line installer:

```powershell
irm https://github.com/aktogde1/pixel-on-pc/releases/latest/download/install.ps1 | iex
```

For a reviewable installation, download `install.ps1` from the latest release, inspect it, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

No administrator privileges are required. Files are installed under `%LOCALAPPDATA%\PixelOnPC`. A **Pixel on PC** shortcut is created on the desktop and in the Start menu.

## Phone setup

1. Open **Settings → About phone** and tap **Build number** seven times if Developer options are hidden.
2. Open **Settings → System → Developer options** and enable **USB debugging**.
3. Connect the unlocked Pixel by USB and accept the RSA fingerprint prompt.
4. Open the **Pixel on PC** shortcut.

The default profile uses 1920×1080, 200 DPI, up to 60 fps, hardware H.264 when available, UHID keyboard/mouse and a 16 Mbps stream. Closing the scrcpy window restores and wakes the phone OLED without unlocking the lockscreen.

## CLI

From `%LOCALAPPDATA%\PixelOnPC\app`:

```powershell
pixel-on-pc.cmd start
pixel-on-pc.cmd diagnose -Output diagnostics.txt
pixel-on-pc.cmd configure
pixel-on-pc.cmd version
pixel-on-pc.cmd uninstall
```

Temporary launch overrides:

```powershell
pixel-on-pc.cmd start -Resolution 2560x1440 -Dpi 240 -Fps 60
pixel-on-pc.cmd start -Windowed -KeepPhoneScreenOn
```

## Android 17 desktop limitation

The current official scrcpy 4.1 creates a separate system-decorated virtual display and Android provides its secondary-display launcher. Android 17 does not currently promote this scrcpy virtual display to the complete desktop-first windowing experience available on a physical external display. The workspace, keyboard, mouse, audio and OLED control work; fully decorated DeX-like freeform windows are not guaranteed.

Pixel on PC does not enable the old global `force_desktop_mode_on_external_displays` setting and does not install a third-party launcher.

See [the technical note](docs/ANDROID-17-DESKTOP-LIMITATION.md).

## Security

- scrcpy is downloaded only from the official Genymobile GitHub release.
- Both the Pixel on PC release archive and scrcpy archive are SHA-256 verified.
- No root, bootloader unlock, factory reset or permanent Android desktop flags.
- Wireless ADB is never enabled automatically.
- No telemetry.
- Diagnostics redact device serial numbers and network endpoints.

## Documentation

- [Setup](docs/SETUP.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Russian README](README.ru.md)
- [Security policy](SECURITY.md)

## License

Pixel on PC is licensed under the [MIT License](LICENSE). scrcpy is a separate project distributed under its own Apache License 2.0.
