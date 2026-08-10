param(
    [string]$AshitaRoot = 'C:\Games\CatsEyeXI\catseyexi-client\Ashita'
)

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'ashitamove'
$destination = Join-Path $AshitaRoot 'addons\ashitamove'

if (-not (Test-Path -LiteralPath $source)) {
    throw "Addon source not found: $source"
}

New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item -LiteralPath (Join-Path $source 'ashitamove.lua') -Destination $destination -Force

Write-Host "Installed ashitamove to $destination"
Write-Host 'Load in game with: /addon load ashitamove'
