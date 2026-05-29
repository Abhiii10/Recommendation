$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$envFiles = @(
  Get-ChildItem -Path $ProjectRoot -Recurse -Force -File -Filter '.env' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
)

foreach ($file in $envFiles) {
  $bytes = [System.IO.File]::ReadAllBytes($file.FullName)

  if ($bytes.Length -ge 3 -and
      $bytes[0] -eq 0xEF -and
      $bytes[1] -eq 0xBB -and
      $bytes[2] -eq 0xBF) {
    if ($bytes.Length -eq 3) {
      $bytes = [byte[]]::new(0)
    } else {
      $bytes = $bytes[3..($bytes.Length - 1)]
    }
  }

  $text = $Utf8NoBom.GetString($bytes)

  $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

  [System.IO.File]::WriteAllText($file.FullName, $text, $Utf8NoBom)
  Write-Host "Fixed env file: $($file.FullName)"
}

if ($envFiles.Count -eq 0) {
  Write-Host "No .env files found under $ProjectRoot"
}
