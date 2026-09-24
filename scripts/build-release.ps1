param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$version = (Get-Content -Raw (Join-Path $RepositoryRoot 'VERSION')).Trim()
$dist = Join-Path $RepositoryRoot 'dist'
$stage = Join-Path $dist "pixel-on-pc-v$version"
Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item (Join-Path $RepositoryRoot 'src') $stage -Recurse
Copy-Item (Join-Path $RepositoryRoot 'VERSION'),(Join-Path $RepositoryRoot 'scrcpy-manifest.json'),(Join-Path $RepositoryRoot 'LICENSE'),(Join-Path $RepositoryRoot 'README.md') $stage
$zip = Join-Path $dist "pixel-on-pc-v$version.zip"
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'), "$hash  $(Split-Path -Leaf $zip)`n", [Text.UTF8Encoding]::new($false))
Copy-Item (Join-Path $RepositoryRoot 'install.ps1') (Join-Path $dist 'install.ps1') -Force
Write-Host "Built $zip"
