param(
    [string]$Domain = "yas.local"
)

$ErrorActionPreference = "Stop"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$entry = "127.0.0.1 storefront.$Domain backoffice.$Domain api.$Domain grafana.$Domain identity.$Domain"

$current = Get-Content $hostsPath -ErrorAction Stop
if ($current -contains $entry) {
    Write-Host "Hosts entry already exists:" -ForegroundColor Green
    Write-Host $entry
    exit 0
}

Add-Content -Path $hostsPath -Value "`r`n# Project 02 YAS local domains"
Add-Content -Path $hostsPath -Value $entry
Write-Host "Added hosts entry:" -ForegroundColor Green
Write-Host $entry
