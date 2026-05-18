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

$storePort = Get-NodePort "storefront-bff"
$backPort = Get-NodePort "backoffice-bff"
$swaggerPort = Get-NodePort "swagger-ui"
$grafanaPort = "N/A"

$grafanaSvcs = kubectl get svc -A -o jsonpath='{range .items[?(@.metadata.name=="grafana")]}{.metadata.namespace}{"/"}{.metadata.name}{" "}{.spec.ports[0].nodePort}{"\n"}{end}' 2>$null
if ($grafanaSvcs) {
    $first = ($grafanaSvcs -split "\r?\n" | Where-Object { $_ -match "grafana" } | Select-Object -First 1)
    if ($first) { $grafanaPort = ($first -split " ")[-1] }
}

Write-Host ""
Write-Host "=== Developer access URLs on Docker Desktop Kubernetes ===" -ForegroundColor Green
Write-Host "Storefront BFF : http://localhost:$storePort"
Write-Host "Backoffice BFF : http://localhost:$backPort"
Write-Host "Swagger UI     : http://localhost:$swaggerPort"
if ($grafanaPort -ne "N/A" -and $grafanaPort -ne "<none>") { Write-Host "Grafana        : http://localhost:$grafanaPort" }
Write-Host ""
Write-Host "Optional hosts entry for report/demo domain:" -ForegroundColor Cyan
Write-Host "127.0.0.1 storefront.$Domain backoffice.$Domain api.$Domain grafana.$Domain identity.$Domain"
Write-Host ""
