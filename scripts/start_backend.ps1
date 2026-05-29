$ErrorActionPreference = "Stop"

$Port = 8000
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..")

Set-Location $RootDir

Write-Host "Checking port $Port..."
$netstatLines = netstat -ano | findstr ":$Port"
$pids = @()

foreach ($line in $netstatLines) {
    $parts = $line -split "\s+" | Where-Object { $_ -ne "" }
    if ($parts.Length -lt 5) {
        continue
    }

    $localAddress = $parts[1]
    $processId = $parts[-1]

    if ($localAddress -match ":$Port$" -and $processId -match "^\d+$" -and $processId -ne "0") {
        $pids += $processId
    }
}

$pids = $pids | Sort-Object -Unique

foreach ($processId in $pids) {
    Write-Host "Killing process $processId on port $Port..."
    taskkill /PID $processId /F | Out-Host
}

Write-Host "Starting FastAPI backend on port $Port..."
uvicorn backend.main:app --host 0.0.0.0 --port $Port --reload
