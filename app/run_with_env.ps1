$ErrorActionPreference = 'Stop'

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $appDir

$backendUrlOverride = $null
$remainingArgs = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $args.Count; $i++) {
  if ($args[$i] -eq '--backend-url') {
    if ($i + 1 -ge $args.Count) {
      throw 'Missing value after --backend-url.'
    }
    $backendUrlOverride = $args[$i + 1]
    $i++
    continue
  }

  $remainingArgs.Add($args[$i])
}

function Read-EnvValue {
  param(
    [Parameter(Mandatory = $true)]
    [string[]] $Paths,
    [Parameter(Mandatory = $true)]
    [string] $Key
  )

  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path)) {
      continue
    }

    $lines = Get-Content -LiteralPath $path
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
  }

  return $null
}

$envFiles = @(
  (Join-Path $appDir '.env'),
  (Join-Path $projectDir '.env')
)

$backendUrl = if ($backendUrlOverride) {
  $backendUrlOverride.Trim()
} else {
  Read-EnvValue -Paths $envFiles -Key 'AI_BACKEND_BASE_URL'
}

if (-not $backendUrl) {
  $backendUrl = 'http://127.0.0.1:8000'
}

Write-Host "Using AI_BACKEND_BASE_URL=$backendUrl" -ForegroundColor Cyan

Push-Location $appDir
try {
  $flutterArgs = New-Object System.Collections.Generic.List[string]
  $flutterArgs.Add('run')
  $flutterArgs.Add("--dart-define=AI_BACKEND_BASE_URL=$backendUrl")
  foreach ($arg in $remainingArgs) {
    $flutterArgs.Add($arg)
  }

  & flutter @flutterArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
