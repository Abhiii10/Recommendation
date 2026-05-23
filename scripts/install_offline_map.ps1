param(
  [Parameter(Mandatory = $true)]
  [string] $MbTilesPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$targetPath = Join-Path $projectDir 'app\assets\maps\pokhara.mbtiles'

$resolved = Resolve-Path -LiteralPath $MbTilesPath -ErrorAction Stop
$sourcePath = $resolved.Path
$sourceFile = Get-Item -LiteralPath $sourcePath

if ($sourceFile.Length -lt 65536) {
  throw "MBTiles file is too small to be useful: $sourcePath"
}

$expectedHeader = [byte[]](
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00
)

$stream = [System.IO.File]::OpenRead($sourcePath)
try {
  $buffer = New-Object byte[] 16
  $read = $stream.Read($buffer, 0, $buffer.Length)
  if ($read -ne 16) {
    throw "Could not read MBTiles header: $sourcePath"
  }

  for ($i = 0; $i -lt $expectedHeader.Length; $i++) {
    if ($buffer[$i] -ne $expectedHeader[$i]) {
      throw "File is not a valid SQLite/MBTiles database: $sourcePath"
    }
  }
} finally {
  $stream.Dispose()
}

Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force

Write-Host "Installed offline map:" -ForegroundColor Green
Write-Host "  Source: $sourcePath"
Write-Host "  Target: $targetPath"
Write-Host "  Size:   $([math]::Round($sourceFile.Length / 1MB, 2)) MB"
