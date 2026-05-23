param(
  [int] $BackendPort = 8000,
  [string] $BackendUrl = '',
  [string] $DeviceId = '',
  [switch] $NoImpeller,
  [switch] $Profile,
  [switch] $SkipFlutter,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $FlutterArgs
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$appDir = Join-Path $projectDir 'app'
$appEnvPath = Join-Path $appDir '.env'
$backendOutLog = Join-Path $projectDir 'backend_phone.out.log'
$backendErrLog = Join-Path $projectDir 'backend_phone.err.log'

function Get-LanIPv4 {
  $gatewayConfigs = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' }

  foreach ($config in $gatewayConfigs) {
    foreach ($address in $config.IPv4Address) {
      if ($address.IPAddress -and
          -not $address.IPAddress.StartsWith('127.') -and
          -not $address.IPAddress.StartsWith('169.254.')) {
        return $address.IPAddress
      }
    }
  }

  $fallback = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
      $_.IPAddress -and
      -not $_.IPAddress.StartsWith('127.') -and
      -not $_.IPAddress.StartsWith('169.254.')
    } |
    Select-Object -First 1

  if ($fallback) {
    return $fallback.IPAddress
  }

  throw 'Could not detect a LAN IPv4 address. Pass -BackendUrl manually.'
}

function Set-EnvValue {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [string] $Key,
    [Parameter(Mandatory = $true)]
    [string] $Value
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType File -Path $Path -Force | Out-Null
  }

  $lines = @(Get-Content -LiteralPath $Path)
  $prefix = "$Key="
  $updated = $false

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].TrimStart().StartsWith($prefix)) {
      $lines[$i] = "$Key=$Value"
      $updated = $true
      break
    }
  }

  if (-not $updated) {
    $lines += "$Key=$Value"
  }

  Set-Content -LiteralPath $Path -Value $lines
}

if (-not $BackendUrl.Trim()) {
  $BackendUrl = "http://$(Get-LanIPv4):$BackendPort"
}

Set-EnvValue -Path $appEnvPath -Key 'AI_BACKEND_BASE_URL' -Value $BackendUrl

$python = Join-Path $projectDir '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
  $python = 'python'
}

$healthUrl = "http://127.0.0.1:$BackendPort/health"
$backendReady = $false
try {
  Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2 | Out-Null
  $backendReady = $true
} catch {
  $backendReady = $false
}

if (-not $backendReady) {
  Write-Host "Starting backend on 0.0.0.0:$BackendPort..." -ForegroundColor Cyan
  $arguments = @(
    '-m', 'uvicorn', 'backend.main:app',
    '--host', '0.0.0.0',
    '--port', $BackendPort.ToString()
  )

  Start-Process `
    -FilePath $python `
    -ArgumentList $arguments `
    -WorkingDirectory $projectDir `
    -RedirectStandardOutput $backendOutLog `
    -RedirectStandardError $backendErrLog `
    -WindowStyle Hidden

  $deadline = (Get-Date).AddSeconds(45)
  do {
    Start-Sleep -Milliseconds 800
    try {
      Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2 | Out-Null
      $backendReady = $true
    } catch {
      $backendReady = $false
    }
  } while (-not $backendReady -and (Get-Date) -lt $deadline)
}

if (-not $backendReady) {
  throw "Backend did not become healthy. Check $backendErrLog"
}

Write-Host "Backend ready: $healthUrl" -ForegroundColor Green
Write-Host "Phone app URL: $BackendUrl" -ForegroundColor Green

if ($SkipFlutter) {
  return
}

$runner = Join-Path $appDir 'run_with_env.ps1'
$runArgs = @('--backend-url', $BackendUrl)
if ($DeviceId.Trim()) {
  $runArgs += @('-d', $DeviceId)
}
if ($Profile) {
  $runArgs += '--profile'
}
if ($NoImpeller) {
  $runArgs += '--no-enable-impeller'
}
$runArgs += $FlutterArgs

& $runner @runArgs
