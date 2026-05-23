param(
  [switch] $SkipAnalyze,
  [switch] $TestLlm
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$appDir = Join-Path $projectDir 'app'
$rootEnvPath = Join-Path $projectDir '.env'
$appEnvPath = Join-Path $appDir '.env'
$mbtilesPath = Join-Path $appDir 'assets\maps\pokhara.mbtiles'

$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Get-EnvValue {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [string] $Key
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return ''
  }

  $lines = @(Get-Content -LiteralPath $Path)
  [array]::Reverse($lines)
  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) {
      continue
    }
    $prefix = "$Key="
    if ($trimmed.StartsWith($prefix)) {
      return $trimmed.Substring($prefix.Length).Trim().Trim('"').Trim("'")
    }
  }

  return ''
}

function Test-SqliteHeader {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return $false
  }

  $expected = [byte[]](
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00
  )
  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $buffer = New-Object byte[] 16
    if ($stream.Read($buffer, 0, $buffer.Length) -ne 16) {
      return $false
    }
    for ($i = 0; $i -lt $expected.Length; $i++) {
      if ($buffer[$i] -ne $expected[$i]) {
        return $false
      }
    }
  } finally {
    $stream.Dispose()
  }

  return $true
}

$backendUrl = Get-EnvValue -Path $appEnvPath -Key 'AI_BACKEND_BASE_URL'
if (-not $backendUrl) {
  $issues.Add('app/.env is missing AI_BACKEND_BASE_URL.')
} elseif ($backendUrl -match 'localhost|127\.0\.0\.1') {
  $warnings.Add("AI_BACKEND_BASE_URL points to localhost. Physical phones need your laptop LAN IP or a deployed HTTPS backend.")
}

$geminiKey = Get-EnvValue -Path $rootEnvPath -Key 'GEMINI_API_KEY'
if (-not $geminiKey) {
  $issues.Add('Root .env is missing GEMINI_API_KEY, so backend chatbot will return 503.')
}

$sentryDsn = Get-EnvValue -Path $appEnvPath -Key 'SENTRY_DSN'
if (-not $sentryDsn) {
  $warnings.Add('SENTRY_DSN is blank. This is fine locally, but production crash reporting will be disabled.')
}

$posthogKey = Get-EnvValue -Path $appEnvPath -Key 'POSTHOG_API_KEY'
if (-not $posthogKey) {
  $warnings.Add('POSTHOG_API_KEY is blank. This is fine locally, but production analytics will be disabled.')
}

if (-not (Test-Path -LiteralPath $mbtilesPath)) {
  $issues.Add('Offline map file is missing: app/assets/maps/pokhara.mbtiles.')
} else {
  $mapFile = Get-Item -LiteralPath $mbtilesPath
  if ($mapFile.Length -lt 65536 -or -not (Test-SqliteHeader -Path $mbtilesPath)) {
    $warnings.Add('Offline map is still a placeholder or invalid MBTiles file. Online map fallback will be used.')
  }
}

$backendHealthOk = $false
if ($backendUrl) {
  try {
    $health = "$($backendUrl.TrimEnd('/'))/health"
    Invoke-WebRequest -Uri $health -UseBasicParsing -TimeoutSec 5 | Out-Null
    $backendHealthOk = $true
    Write-Host "Backend health OK: $health" -ForegroundColor Green
  } catch {
    $warnings.Add("Could not reach backend health endpoint at $backendUrl/health.")
  }
}

if ($TestLlm -and $backendHealthOk) {
  try {
    $chatUrl = "$($backendUrl.TrimEnd('/'))/chat"
    $body = @{
      question = 'Suggest one rural tourism place near Pokhara.'
      language = 'en'
      top_k = 3
    } | ConvertTo-Json
    Invoke-WebRequest `
      -Uri $chatUrl `
      -Method Post `
      -ContentType 'application/json' `
      -Body $body `
      -UseBasicParsing `
      -TimeoutSec 60 | Out-Null
    Write-Host "LLM chat OK: $chatUrl" -ForegroundColor Green
  } catch {
    $message = $_.Exception.Message
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
      $message = $_.ErrorDetails.Message
    }
    if ($message.Length -gt 500) {
      $message = $message.Substring(0, 500) + '...'
    }
    $issues.Add("LLM chat test failed: $message")
  }
}

if (-not $SkipAnalyze) {
  Push-Location $appDir
  try {
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
      $issues.Add('flutter analyze failed.')
    }
  } finally {
    Pop-Location
  }
}

if ($warnings.Count -gt 0) {
  Write-Host "`nWarnings:" -ForegroundColor Yellow
  foreach ($warning in $warnings) {
    Write-Host "  - $warning" -ForegroundColor Yellow
  }
}

if ($issues.Count -gt 0) {
  Write-Host "`nBlocking issues:" -ForegroundColor Red
  foreach ($issue in $issues) {
    Write-Host "  - $issue" -ForegroundColor Red
  }
  exit 1
}

Write-Host "`nProduction readiness checks completed." -ForegroundColor Green
