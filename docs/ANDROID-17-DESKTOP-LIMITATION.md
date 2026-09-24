# Android 17 desktop windowing limitation

Android 17 supports per-display desktop windowing and normally selects desktop-first behavior for eligible physical external displays with keyboard and pointer input.

scrcpy 4.1 creates a trusted virtual display with system decorations and task hosting. Android provides `SecondaryDisplayLauncher`, but the virtual display is not automatically treated exactly like a physical external display. Forcing only its task display area to freeform with `wm set-display-windowing-mode` changes task bounds but did not provide complete, reliable window decorations in testing.

An upstream draft pull request discusses assigning freeform mode after virtual display creation: <https://github.com/Genymobile/scrcpy/pull/6722>. Pixel on PC uses only official Genymobile releases and will not ship an unreviewed build from that branch.

References:

- <https://source.android.com/docs/core/display/desktop-windowing>
- <https://github.com/Genymobile/scrcpy/blob/v4.1/doc/virtual-display.md>
