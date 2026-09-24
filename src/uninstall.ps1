[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$installRoot = Split-Path -Parent $PSScriptRoot
$marker = Join-Path $installRoot '.pixel-on-pc-install'
if (-not (Test-Path -LiteralPath $marker)) { throw "Refusing to remove an unrecognized directory: $installRoot" }
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Pixel on PC.lnk'
$startShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'Pixel on PC.lnk'
if ($PSCmdlet.ShouldProcess($installRoot, 'Uninstall Pixel on PC')) {
    Remove-Item -LiteralPath $desktopShortcut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $startShortcut -Force -ErrorAction SilentlyContinue
    Write-Host "Removing $installRoot"
    Start-Process cmd.exe -WindowStyle Hidden -ArgumentList '/d','/c',("ping 127.0.0.1 -n 3 >nul & rmdir /s /q `"{0}`"" -f $installRoot) | Out-Null
}
