param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath
)

$ErrorActionPreference = 'Stop'
$resolvedScript = (Resolve-Path -LiteralPath $ScriptPath).Path
$lines = [System.IO.File]::ReadAllLines($resolvedScript)
$alreadyEnabled = $lines | Where-Object { $_ -match '^\s*/addon\s+load\s+ashitamove\s*$' }
if ($alreadyEnabled) {
    Write-Host 'AshitaMove is already enabled in the startup script.'
    exit 0
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$resolvedScript.$timestamp.bak"
Copy-Item -LiteralPath $resolvedScript -Destination $backupPath

[System.IO.File]::AppendAllText(
    $resolvedScript,
    [Environment]::NewLine + '/addon load ashitamove' + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host 'Enabled AshitaMove in the startup script.'
Write-Host "Backup: $backupPath"
