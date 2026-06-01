param(
    [int] $Port = 8000,
    [switch] $ForceRestart
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..")

Set-Location $RootDir

$VenvPython = Join-Path $RootDir ".venv\Scripts\python.exe"
if (Test-Path $VenvPython) {
    $Python = $VenvPython
} else {
    $Python = "python"
}

function Test-BackendHealth {
    param([Parameter(Mandatory = $true)][int] $Port)

    try {
        Invoke-WebRequest `
            -Uri "http://127.0.0.1:$Port/health" `
            -UseBasicParsing `
            -TimeoutSec 3 | Out-Null
        return $true
    } catch {
        return $false
    }
}

if (-not $ForceRestart -and (Test-BackendHealth -Port $Port)) {
    Write-Host "Backend is already running and healthy on port $Port." -ForegroundColor Green
    Write-Host "Use -ForceRestart if you intentionally want to stop it and start local uvicorn."
    return
}

Write-Host "Checking port $Port..."
$netstatLines = @(netstat -ano | findstr ":$Port")
$pids = @()

foreach ($line in $netstatLines) {
    $parts = $line -split "\s+" | Where-Object { $_ -ne "" }
    if ($parts.Length -lt 5) {
        continue
    }

    $localAddress = $parts[1]
    $state = $parts[-2]
    $processId = $parts[-1]

    if ($localAddress -match ":$Port$" -and $state -eq "LISTENING" -and $processId -match "^\d+$" -and $processId -ne "0") {
        $pids += $processId
    }
}

$pids = $pids | Sort-Object -Unique

foreach ($processId in $pids) {
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if (-not $process) {
        continue
    }

    if ($process.ProcessName -in @("com.docker.backend", "wslrelay")) {
        if (-not $ForceRestart) {
            Write-Host "Port $Port is owned by Docker/WSL process $processId ($($process.ProcessName))." -ForegroundColor Yellow
            Write-Host "Backend may already be running in Docker. Run 'docker compose ps' or use -ForceRestart to stop the compose backend safely."
            continue
        }

        Write-Host "Stopping Docker backend service instead of killing Docker Desktop..." -ForegroundColor Yellow
        docker compose stop backend | Out-Host
        continue
    }

    Write-Host "Killing process $processId ($($process.ProcessName)) on port $Port..."
    taskkill /PID $processId /F | Out-Host
}

if ($ForceRestart) {
    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 500
        $stillBusy = @(
            netstat -ano |
                findstr ":$Port" |
                Where-Object { $_ -match "\sLISTENING\s" }
        )
    } while ($stillBusy.Count -gt 0 -and (Get-Date) -lt $deadline)
}

if (-not $ForceRestart -and -not (Test-BackendHealth -Port $Port)) {
    $stillBusy = @(
        netstat -ano |
            findstr ":$Port" |
            Where-Object { $_ -match "\sLISTENING\s" }
    )
    if ($stillBusy.Count -gt 0) {
        throw "Port $Port is still occupied. Stop Docker with 'docker compose stop backend' or rerun '.\scripts\start_backend.ps1 -ForceRestart'."
    }
}

$remainingBusy = @(
    netstat -ano |
        findstr ":$Port" |
        Where-Object { $_ -match "\sLISTENING\s" }
)
if ($remainingBusy.Count -gt 0) {
    throw "Port $Port is still occupied after cleanup. Cannot start uvicorn."
}

Write-Host "Starting FastAPI backend on port $Port..."
& $Python -m uvicorn backend.main:app --host 0.0.0.0 --port $Port --reload
