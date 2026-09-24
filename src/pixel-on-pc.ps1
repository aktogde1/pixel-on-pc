[CmdletBinding()]
param(
    [ValidateSet('start', 'diagnose', 'version', 'configure', 'uninstall')]
    [string]$Command = 'start',
    [string]$Serial,
    [string]$Resolution,
    [int]$Dpi,
    [int]$Fps,
    [switch]$Windowed,
    [switch]$KeepPhoneScreenOn,
    [string]$Output
)

$ErrorActionPreference = 'Stop'
$script:InstallRoot = Split-Path -Parent $PSScriptRoot
$script:ConfigPath = Join-Path $script:InstallRoot 'config.json'
$script:VersionPath = Join-Path $script:InstallRoot 'VERSION'
$script:ManifestPath = Join-Path $script:InstallRoot 'scrcpy-manifest.json'

function Stop-PixelOnPc([string]$Message, [int]$Code = 1) {
    Write-Host "Pixel on PC: $Message" -ForegroundColor Red
    exit $Code
}

function Get-PixelConfig {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        Stop-PixelOnPc "Configuration not found: $script:ConfigPath"
    }
    Get-Content -Raw -LiteralPath $script:ConfigPath | ConvertFrom-Json
}

function Get-ScrcpyPaths {
    $manifest = Get-Content -Raw -LiteralPath $script:ManifestPath | ConvertFrom-Json
    $directory = Join-Path $script:InstallRoot ("vendor\scrcpy-win64-v{0}" -f $manifest.version)
    $adb = Join-Path $directory 'adb.exe'
    $scrcpy = Join-Path $directory 'scrcpy.exe'
    if (-not (Test-Path -LiteralPath $adb) -or -not (Test-Path -LiteralPath $scrcpy)) {
        Stop-PixelOnPc 'scrcpy is missing. Run install.ps1 again.'
    }
    [pscustomobject]@{ Adb = $adb; Scrcpy = $scrcpy; Directory = $directory; Manifest = $manifest }
}

function Get-AdbDevices([string]$Adb) {
    $lines = @(& $Adb devices -l 2>&1)
    if ($LASTEXITCODE -ne 0) { Stop-PixelOnPc "ADB failed:`n$($lines -join "`n")" }
    foreach ($line in $lines) {
        if ($line -match '^(?<serial>\S+)\s+(?<state>device|unauthorized|offline)\b(?<details>.*)$') {
            [pscustomobject]@{ Serial = $Matches.serial; State = $Matches.state; Details = $Matches.details.Trim() }
        }
    }
}

function Select-AdbDevice([string]$Adb, [string]$RequestedSerial) {
    $devices = @(Get-AdbDevices $Adb)
    if ($RequestedSerial) {
        $selected = $devices | Where-Object Serial -eq $RequestedSerial | Select-Object -First 1
        if (-not $selected) { Stop-PixelOnPc "Device '$RequestedSerial' was not found." }
    } else {
        $authorized = @($devices | Where-Object State -eq 'device')
        if ($authorized.Count -eq 0) {
            if ($devices.State -contains 'unauthorized') {
                Stop-PixelOnPc 'Device is unauthorized. Unlock the phone and accept the USB debugging RSA prompt.'
            }
            if ($devices.State -contains 'offline') { Stop-PixelOnPc 'Device is offline. Reconnect USB and retry.' }
            Stop-PixelOnPc 'No Android device found. Connect an unlocked Pixel with USB debugging enabled.'
        }
        if ($authorized.Count -gt 1) {
            Write-Host 'Connected devices:'
            $authorized | ForEach-Object { Write-Host "  $($_.Serial) $($_.Details)" }
            Stop-PixelOnPc 'More than one device is connected. Retry with -Serial DEVICE_SERIAL.'
        }
        $selected = $authorized[0]
    }
    if ($selected.State -ne 'device') { Stop-PixelOnPc "Device state is $($selected.State)." }
    $selected
}

function Get-DisplayIds([string]$Adb, [string]$DeviceSerial) {
    @(& $Adb -s $DeviceSerial shell cmd display get-displays -i 2>$null | Where-Object { $_ -match '^\d+$' })
}

function Write-Diagnostics([string]$Destination) {
    $paths = Get-ScrcpyPaths
    $devices = @(Get-AdbDevices $paths.Adb)
    $safeDevices = $devices | ForEach-Object {
        [pscustomobject]@{ Serial = '<redacted>'; State = $_.State; Details = ($_.Details -replace '\b\d{1,3}(?:\.\d{1,3}){3}:\d+\b', '<redacted-ip>') }
    }
    $report = [System.Collections.Generic.List[string]]::new()
    $report.Add('Pixel on PC diagnostics')
    $report.Add("Generated: $([DateTime]::UtcNow.ToString('u')) UTC")
    $report.Add("Version: $((Get-Content -Raw $script:VersionPath).Trim())")
    $report.Add("Windows: $([Environment]::OSVersion.VersionString)")
    $report.Add("Architecture: $([Runtime.InteropServices.RuntimeInformation]::OSArchitecture)")
    $report.Add('')
    $report.Add('scrcpy:')
    $report.AddRange([string[]]@(& $paths.Scrcpy --version 2>&1))
    $report.Add('')
    $report.Add('ADB devices (identifiers redacted):')
    $report.AddRange([string[]]@($safeDevices | Format-Table -AutoSize | Out-String -Stream))
    $authorized = $devices | Where-Object State -eq 'device' | Select-Object -First 1
    if ($authorized) {
        $report.Add('')
        $report.Add("Model: $(& $paths.Adb -s $authorized.Serial shell getprop ro.product.model)")
        $report.Add("Android: $(& $paths.Adb -s $authorized.Serial shell getprop ro.build.version.release) (API $(& $paths.Adb -s $authorized.Serial shell getprop ro.build.version.sdk))")
        $report.Add("Build: $(& $paths.Adb -s $authorized.Serial shell getprop ro.build.display.id)")
        $report.Add("Security patch: $(& $paths.Adb -s $authorized.Serial shell getprop ro.build.version.security_patch)")
        $report.Add('Displays:')
        $report.AddRange([string[]]@(& $paths.Adb -s $authorized.Serial shell cmd display get-displays 2>&1))
    }
    $text = $report -join [Environment]::NewLine
    if ($Destination) {
        [IO.File]::WriteAllText((Join-Path (Get-Location) $Destination), $text, [Text.UTF8Encoding]::new($false))
        Write-Host "Diagnostic report written to $Destination"
    } else { $text }
}

function Start-PixelWorkspace {
    $paths = Get-ScrcpyPaths
    $config = Get-PixelConfig
    $device = Select-AdbDevice $paths.Adb $Serial
    $selectedResolution = if ($Resolution) { $Resolution } else { [string]$config.resolution }
    $selectedDpi = if ($Dpi -gt 0) { $Dpi } else { [int]$config.dpi }
    $selectedFps = if ($Fps -gt 0) { $Fps } else { [int]$config.maxFps }
    if ($selectedResolution -notmatch '^\d{3,5}x\d{3,5}$') { Stop-PixelOnPc 'Resolution must look like 1920x1080.' }
    if ($selectedDpi -lt 120 -or $selectedDpi -gt 640) { Stop-PixelOnPc 'DPI must be between 120 and 640.' }
    if ($selectedFps -lt 15 -or $selectedFps -gt 240) { Stop-PixelOnPc 'FPS must be between 15 and 240.' }

    $beforeDisplays = @(Get-DisplayIds $paths.Adb $device.Serial)
    $arguments = @(
        '--serial', $device.Serial,
        "--new-display=$selectedResolution/$selectedDpi",
        '--flex-display', '--keep-active',
        "--keyboard=$($config.keyboard)", "--mouse=$($config.mouse)",
        "--max-fps=$selectedFps", "--video-codec=$($config.videoCodec)",
        "--video-bit-rate=$($config.videoBitRate)",
        "--display-ime-policy=$($config.displayImePolicy)",
        '--no-vd-destroy-content', '--no-power-on',
        '--window-title="Pixel on PC"'
    )
    if ($config.fullscreen -and -not $Windowed) { $arguments += '--fullscreen' }

    Write-Host "Starting Pixel workspace: $selectedResolution, $selectedDpi DPI, up to $selectedFps fps..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $paths.Scrcpy -WorkingDirectory $paths.Directory -ArgumentList $arguments -PassThru
    $virtualDisplay = $null
    for ($attempt = 0; $attempt -lt 40 -and -not $process.HasExited; $attempt++) {
        Start-Sleep -Milliseconds 250
        $currentDisplays = @(Get-DisplayIds $paths.Adb $device.Serial)
        $virtualDisplay = $currentDisplays | Where-Object { $_ -ne '0' -and $_ -notin $beforeDisplays } | Select-Object -Last 1
        if ($virtualDisplay) { break }
    }

    if ($virtualDisplay) {
        Write-Host "Virtual display created: ID $virtualDisplay" -ForegroundColor Green
        if ($config.turnPhysicalDisplayOff -and -not $KeepPhoneScreenOn) {
            & $paths.Adb -s $device.Serial shell cmd display power-off 0 2>$null | Out-Null
            Write-Host 'Pixel OLED is off. Close the scrcpy window to restore it.'
        }
    } else { Write-Warning 'Could not identify the virtual display. The scrcpy window will remain open.' }

    $exitCode = 1
    try {
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } finally {
        if ($config.restorePhysicalDisplayOnExit) {
            # scrcpy and Android tear the virtual display down asynchronously.
            # Retry after a short delay so display 0 reliably returns to normal
            # power policy even when the server cleanup wins the first race.
            foreach ($delay in @(250, 750)) {
                Start-Sleep -Milliseconds $delay
                & $paths.Adb -s $device.Serial shell cmd display power-reset 0 2>$null | Out-Null
            }
            # power-reset releases the forced-off policy; WAKEUP then turns the
            # panel on without unlocking the device or weakening the lockscreen.
            & $paths.Adb -s $device.Serial shell input keyevent 224 2>$null | Out-Null
        }
    }
    if ($exitCode -ne 0) { Stop-PixelOnPc "scrcpy exited with code $exitCode." $exitCode }
}

switch ($Command) {
    'start' { Start-PixelWorkspace }
    'diagnose' { Write-Diagnostics $Output }
    'version' { "Pixel on PC $((Get-Content -Raw $script:VersionPath).Trim())" }
    'configure' { Start-Process notepad.exe -ArgumentList ('"{0}"' -f $script:ConfigPath) | Out-Null }
    'uninstall' { & (Join-Path $PSScriptRoot 'uninstall.ps1') }
}
