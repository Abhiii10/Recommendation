param(
  [string] $Target = 'apk',
  [string] $BuildMode = 'release'
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$appDir = Join-Path $projectDir 'app'
$venvPython = Join-Path $projectDir '.venv\Scripts\python.exe'
$python = if (Test-Path -LiteralPath $venvPython) { $venvPython } else { 'python' }

Push-Location $projectDir
try {
  & $python scripts/export_embeddings.py
} finally {
  Pop-Location
}

Push-Location $appDir
try {
  flutter pub get
  flutter build $Target "--$BuildMode"
} finally {
  Pop-Location
}
