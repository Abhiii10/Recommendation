param(
    [string]$InterfaceAlias = "Wi-Fi",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$ruleName = "Paila Nepal Backend $Port"

Write-Host "Configuring LAN access for Paila Nepal backend..." -ForegroundColor Cyan

$profile = Get-NetConnectionProfile -InterfaceAlias $InterfaceAlias -ErrorAction SilentlyContinue
if ($null -eq $profile) {
    Write-Host "Network interface '$InterfaceAlias' was not found." -ForegroundColor Yellow
    Write-Host "Available network profiles:" -ForegroundColor Yellow
    Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory, IPv4Connectivity -AutoSize
    throw "Cannot configure firewall without a valid network interface."
}

if ($profile.NetworkCategory -ne "Private") {
    Write-Host "Changing '$InterfaceAlias' network from $($profile.NetworkCategory) to Private..."
    Set-NetConnectionProfile -InterfaceAlias $InterfaceAlias -NetworkCategory Private
} else {
    Write-Host "'$InterfaceAlias' is already Private."
}

$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($null -eq $existingRule) {
    Write-Host "Creating inbound firewall rule for TCP port $Port..."
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $Port `
        -Profile Any | Out-Null
} else {
    Write-Host "Firewall rule '$ruleName' already exists."
    Set-NetFirewallRule -DisplayName $ruleName -Enabled True -Action Allow -Profile Any
}

$ip = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -like "192.168.*" } |
    Select-Object -First 1 -ExpandProperty IPAddress

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Test from your phone browser on the same Wi-Fi:" -ForegroundColor Cyan
Write-Host "http://$ip`:$Port/health" -ForegroundColor White
Write-Host ""
Write-Host "Flutter command:" -ForegroundColor Cyan
Write-Host "flutter run --dart-define=AI_BACKEND_BASE_URL=http://$ip`:$Port" -ForegroundColor White
