param(
    [string]$Domain = "yas.local"
)

$ErrorActionPreference = "Stop"
$ip = minikube ip
$hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
$line = "$ip storefront.$Domain backoffice.$Domain api.$Domain grafana.$Domain identity.$Domain"

Write-Host "Adding hosts entry. Run this script as Administrator." -ForegroundColor Yellow
Write-Host $line

$content = Get-Content $hostsPath -ErrorAction Stop
$content = $content | Where-Object { $_ -notmatch "storefront\.$Domain|backoffice\.$Domain|api\.$Domain|grafana\.$Domain|identity\.$Domain" }
$content += $line
Set-Content -Path $hostsPath -Value $content -Encoding ASCII

Write-Host "Updated $hostsPath" -ForegroundColor Green
