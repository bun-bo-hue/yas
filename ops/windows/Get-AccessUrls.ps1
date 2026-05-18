param(
    [string]$Namespace = "yas-dev",
    [string]$Domain = "yas.local"
)

function Get-NodePort {
    param([string]$Svc)
    $port = kubectl -n $Namespace get svc $Svc -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($port)) { return "N/A" }
    return $port
}

function Get-MinikubeUrl {
    param([string]$Svc)
    $url = minikube service $Svc -n $Namespace --url 2>$null | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($url)) { return "N/A" }
    return $url
}

$minikubeIp = minikube ip 2>$null
if ([string]::IsNullOrWhiteSpace($minikubeIp)) { $minikubeIp = "<minikube-ip>" }

$storeUiPort = Get-NodePort "storefront-ui"
$storeBffPort = Get-NodePort "storefront-bff"
$backUiPort = Get-NodePort "backoffice-ui"
$backBffPort = Get-NodePort "backoffice-bff"
$swaggerPort = Get-NodePort "swagger-ui"

$storeUiUrl = Get-MinikubeUrl "storefront-ui"
$storeBffUrl = Get-MinikubeUrl "storefront-bff"
$backUiUrl = Get-MinikubeUrl "backoffice-ui"
$backBffUrl = Get-MinikubeUrl "backoffice-bff"
$swaggerUrl = Get-MinikubeUrl "swagger-ui"

Write-Host ""
Write-Host "=== Developer access URLs on Minikube ===" -ForegroundColor Green
Write-Host "Minikube IP    : $minikubeIp"
Write-Host "Storefront UI  : http://${minikubeIp}:$storeUiPort"
Write-Host "Storefront BFF : http://${minikubeIp}:$storeBffPort"
Write-Host "Backoffice UI  : http://${minikubeIp}:$backUiPort"
Write-Host "Backoffice BFF : http://${minikubeIp}:$backBffPort"
Write-Host "Swagger UI     : http://${minikubeIp}:$swaggerPort"
Write-Host ""
Write-Host "Alternative URLs from minikube service --url:" -ForegroundColor Cyan
Write-Host "Storefront UI  : $storeUiUrl"
Write-Host "Storefront BFF : $storeBffUrl"
Write-Host "Backoffice UI  : $backUiUrl"
Write-Host "Backoffice BFF : $backBffUrl"
Write-Host "Swagger UI     : $swaggerUrl"
Write-Host ""
Write-Host "Optional hosts entry for domain demo:" -ForegroundColor Cyan
Write-Host "$minikubeIp storefront.$Domain backoffice.$Domain api.$Domain grafana.$Domain identity.$Domain"
Write-Host ""
