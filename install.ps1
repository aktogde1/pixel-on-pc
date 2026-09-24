[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'PixelOnPC'),
    [string]$SourcePath,
    [string]$ScrcpyArchive,
    [switch]$NoDesktopShortcut,
    [switch]$NoStartMenuShortcut
)

$ErrorActionPreference = 'Stop'
$repository = 'aktogde1/pixel-on-pc'
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("pixel-on-pc-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null

function Copy-ProjectFiles([string]$From) {
    $required = @('src', 'VERSION', 'scrcpy-manifest.json')
    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $From $item))) { throw "Release is missing $item" }
    }
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    $appRoot = Join-Path $InstallRoot 'app'
    Remove-Item -LiteralPath $appRoot -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath (Join-Path $From 'src') -Destination $appRoot -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $From 'VERSION') -Destination $InstallRoot -Force
    Copy-Item -LiteralPath (Join-Path $From 'scrcpy-manifest.json') -Destination $InstallRoot -Force
    $defaultConfig = Join-Path $From 'src\config.default.json'
    $configPath = Join-Path $InstallRoot 'config.json'
    if (-not (Test-Path -LiteralPath $configPath)) { Copy-Item -LiteralPath $defaultConfig -Destination $configPath }
    [IO.File]::WriteAllText((Join-Path $InstallRoot '.pixel-on-pc-install'), 'Pixel on PC', [Text.UTF8Encoding]::new($false))
}

try {
    if ($SourcePath) {
        $projectSource = (Resolve-Path $SourcePath).Path
    } else {
        Write-Host 'Downloading the latest Pixel on PC release...'
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repository/releases/latest" -Headers @{'User-Agent'='Pixel-on-PC-installer'}
        $asset = $release.assets | Where-Object name -like 'pixel-on-pc-v*.zip' | Select-Object -First 1
        $checksumAsset = $release.assets | Where-Object name -eq 'SHA256SUMS.txt' | Select-Object -First 1
        if (-not $asset -or -not $checksumAsset) { throw 'The latest release does not contain the expected archive and checksum.' }
        $projectZip = Join-Path $temporaryRoot $asset.name
        $checksumFile = Join-Path $temporaryRoot 'SHA256SUMS.txt'
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $projectZip
        Invoke-WebRequest -Uri $checksumAsset.browser_download_url -OutFile $checksumFile
        $expected = ((Get-Content $checksumFile | Where-Object { $_ -match [regex]::Escape($asset.name) }) -split '\s+')[0].ToLower()
        $actual = (Get-FileHash $projectZip -Algorithm SHA256).Hash.ToLower()
        if (-not $expected -or $actual -ne $expected) { throw 'Pixel on PC release checksum verification failed.' }
        $projectSource = Join-Path $temporaryRoot 'project'
        Expand-Archive -LiteralPath $projectZip -DestinationPath $projectSource -Force
    }

    Copy-ProjectFiles $projectSource
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $InstallRoot 'scrcpy-manifest.json') | ConvertFrom-Json
    $vendorRoot = Join-Path $InstallRoot 'vendor'
    $scrcpyRoot = Join-Path $vendorRoot ("scrcpy-win64-v{0}" -f $manifest.version)
    if (-not (Test-Path -LiteralPath (Join-Path $scrcpyRoot 'scrcpy.exe'))) {
        New-Item -ItemType Directory -Force -Path $vendorRoot | Out-Null
        $archive = if ($ScrcpyArchive) { (Resolve-Path $ScrcpyArchive).Path } else { Join-Path $temporaryRoot $manifest.asset }
        if (-not $ScrcpyArchive) {
            Write-Host "Downloading official Genymobile scrcpy $($manifest.version)..."
            Invoke-WebRequest -Uri $manifest.url -OutFile $archive
        }
        $actualScrcpyHash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
        if ($actualScrcpyHash -ne $manifest.sha256.ToLower()) { throw 'Official scrcpy archive checksum verification failed.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $vendorRoot -Force
    }

    $launcher = Join-Path $InstallRoot 'app\pixel-on-pc.cmd'
    $shell = New-Object -ComObject WScript.Shell
    if (-not $NoDesktopShortcut) {
        $shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Pixel on PC.lnk'))
        $shortcut.TargetPath = $launcher; $shortcut.WorkingDirectory = $InstallRoot; $shortcut.Description = 'Open a Pixel workspace on this PC'; $shortcut.Save()
    }
    if (-not $NoStartMenuShortcut) {
        $shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'Pixel on PC.lnk'))
        $shortcut.TargetPath = $launcher; $shortcut.WorkingDirectory = $InstallRoot; $shortcut.Description = 'Open a Pixel workspace on this PC'; $shortcut.Save()
    }
    Write-Host ''
    Write-Host 'Pixel on PC installed successfully.' -ForegroundColor Green
    Write-Host "Install directory: $InstallRoot"
    Write-Host "Launcher: $launcher"
    Write-Host 'Connect an unlocked Pixel, enable USB debugging, then open the Pixel on PC shortcut.'
} finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}
