# Uruchom w PowerShell jako Administrator na komputerze, do którego ma działać RDP.
[CmdletBinding()]
param(
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/(?:[0-9]|[12][0-9]|3[0-2])$')]
    [string]$VpnSubnet = "10.77.77.0/24"
)

$ErrorActionPreference = "Stop"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "Uruchom PowerShell jako Administrator."
}

$rules = @(
    @{ Name = "WireGuard-RDP-TCP"; Protocol = "TCP"; Port = 3389 },
    @{ Name = "WireGuard-RDP-UDP"; Protocol = "UDP"; Port = 3389 }
)

foreach ($rule in $rules) {
    Remove-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
    New-NetFirewallRule `
        -Name $rule.Name `
        -DisplayName "RDP z prywatnej sieci WireGuard ($($rule.Protocol))" `
        -Direction Inbound `
        -Action Allow `
        -Protocol $rule.Protocol `
        -LocalPort $rule.Port `
        -RemoteAddress $VpnSubnet `
        -Profile Any | Out-Null
}

Write-Host "Dodano reguły RDP dla źródeł z $VpnSubnet."
