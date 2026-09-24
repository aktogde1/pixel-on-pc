# Troubleshooting

## Device is unauthorized

Unlock the Pixel and accept the USB debugging RSA prompt. If no prompt appears, revoke USB debugging authorizations in Developer options, reconnect the cable, and retry.

## No device found

Confirm the cable supports data, keep the phone unlocked, and check the GrapheneOS USB-C port policy under **Settings → Security → Exploit protection**. A charging-only policy can prevent a new USB data connection while locked.

## OLED stays off after a crash

Press the physical power button. During a normal exit Pixel on PC runs `adb shell cmd display power-reset 0` in a `finally` block.

## Text is too small or large

Run `pixel-on-pc.cmd configure` and adjust `dpi`. Try 180 for more workspace, 200 for the default, or 220 for larger text.

## Create a safe report

```powershell
pixel-on-pc.cmd diagnose -Output diagnostics.txt
```

The report redacts the ADB serial and network endpoints.
