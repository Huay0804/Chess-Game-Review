param([string]$Version = '17.1')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engineRoot = Join-Path $projectRoot 'engine'
New-Item -ItemType Directory -Path $engineRoot -Force | Out-Null
$archive = Join-Path $engineRoot "stockfish-$Version.zip"
$uri = "https://github.com/official-stockfish/Stockfish/releases/download/sf_$Version/stockfish-windows-x86-64.zip"
Write-Host "Downloading official Stockfish $Version (portable x64)..."
curl.exe --location --fail --silent --show-error $uri --output $archive
if ($LASTEXITCODE -ne 0) { throw 'Stockfish download failed.' }
Expand-Archive -LiteralPath $archive -DestinationPath $engineRoot -Force
$binary = Get-ChildItem -LiteralPath (Join-Path $engineRoot 'stockfish') -Filter '*.exe' -File | Select-Object -First 1
if (-not $binary) { throw 'The official archive did not contain an executable.' }
Copy-Item -LiteralPath $binary.FullName -Destination (Join-Path $engineRoot 'stockfish\stockfish.exe') -Force
Write-Host 'Stockfish ready in engine/stockfish. Keep the license and source included in this directory.'
