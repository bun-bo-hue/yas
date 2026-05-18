param(
    [string]$Namespace = $env:NAMESPACE,
    [string]$DockerHubUser = $env:DOCKERHUB_USER,
    [string]$Domain = $env:DOMAIN,
    [string]$ChartsDir = "k8s/charts",
    [string]$TagDefault = "main",
    [string]$KubeConfig = $env:KUBECONFIG
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Namespace)) { $Namespace = "yas-dev" }
if ([string]::IsNullOrWhiteSpace($Domain)) { $Domain = "yas.local" }
if ([string]::IsNullOrWhiteSpace($DockerHubUser)) {
    throw "DOCKERHUB_USER is required. Example: `$env:DOCKERHUB_USER='your_dockerhub_username'"
}

function Import-DotEnv {
    param([string]$Path)
    if (!(Test-Path $Path)) { return }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $parts = $line.Split("=", 2)
        if ($parts.Count -eq 2) {
            [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
        }
    }
}

function Get-TagOf {
    param([string]$ServiceKey)
    $key = $ServiceKey.ToUpper().Replace("-", "_")
    $value = [Environment]::GetEnvironmentVariable("TAG_$key")
    if ([string]::IsNullOrWhiteSpace($value)) { return $TagDefault }
    return $value
}

function Get-RepoFor {
    param([string]$ImageSuffix)
    return "docker.io/$DockerHubUser/yas-$ImageSuffix"
}

function Invoke-Checked {
    param([string]$Command)
    Write-Host "> $Command" -ForegroundColor Cyan
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
}

function Test-ChartPath {
    param([string]$Chart)
    $path = Join-Path $ChartsDir $Chart
    if (!(Test-Path $path)) {
        throw "Chart not found: $path. Make sure you run this from the YAS repository root and k8s/charts exists."
    }
    return $path
}

function Build-Dependency {
    param([string]$Chart)
    $path = Test-ChartPath $Chart
    if (Test-Path (Join-Path $path "Chart.yaml")) {
        Invoke-Checked "helm dependency build `"$path`""
    }
}

function Deploy-BackendChart {
    param([string]$Chart, [string]$ImageSuffix)
    $tag = Get-TagOf $Chart
    $repo = Get-RepoFor $ImageSuffix
    $path = Test-ChartPath $Chart
    Write-Host "=== Deploy backend $Chart -> ${repo}:${tag} ===" -ForegroundColor Green
    Build-Dependency $Chart
    Invoke-Checked "helm upgrade --install $Chart `"$path`" --namespace $Namespace --create-namespace --set backend.image.repository=$repo --set backend.image.tag=$tag --set backend.ingress.host=api.$Domain --set backend.service.type=ClusterIP"
}

function Deploy-BffChart {
    param([string]$Chart, [string]$ImageSuffix, [string]$HostPrefix)
    $tag = Get-TagOf $Chart
    $repo = Get-RepoFor $ImageSuffix
    $path = Test-ChartPath $Chart
    Write-Host "=== Deploy BFF $Chart -> ${repo}:${tag} ===" -ForegroundColor Green
    Build-Dependency $Chart
    Invoke-Checked "helm upgrade --install $Chart `"$path`" --namespace $Namespace --create-namespace --set backend.image.repository=$repo --set backend.image.tag=$tag --set backend.ingress.enabled=true --set backend.ingress.host=$HostPrefix.$Domain --set backend.service.type=ClusterIP"
}

function Deploy-UiChart {
    param([string]$Chart, [string]$ImageSuffix)
    $tag = Get-TagOf $Chart
    $repo = Get-RepoFor $ImageSuffix
    $path = Test-ChartPath $Chart
    Write-Host "=== Deploy UI $Chart -> ${repo}:${tag} ===" -ForegroundColor Green
    Build-Dependency $Chart
    Invoke-Checked "helm upgrade --install $Chart `"$path`" --namespace $Namespace --create-namespace --set ui.image.repository=$repo --set ui.image.tag=$tag --set ui.ingress.enabled=false"
}

function Deploy-YasConfiguration {
    $chart = "yas-configuration"
    $path = Test-ChartPath $chart

    Write-Host "=== Deploy YAS shared configuration ===" -ForegroundColor Green

    Build-Dependency $chart

    Invoke-Checked "helm upgrade --install yas-configuration `"$path`" --namespace $Namespace --create-namespace"

    Write-Host "=== Verify YAS configuration ConfigMaps ===" -ForegroundColor Green
    kubectl -n $Namespace get configmap yas-configuration-configmap | Out-Host
}

Import-DotEnv ".deploy.env"

if (![string]::IsNullOrWhiteSpace($KubeConfig) -and (Test-Path $KubeConfig)) {
    $env:KUBECONFIG = $KubeConfig
}

kubectl config use-context minikube | Out-Host

Write-Host "=== Namespace: $Namespace ===" -ForegroundColor Green
$existingNamespace = kubectl get namespace $Namespace --ignore-not-found -o name
if ([string]::IsNullOrWhiteSpace($existingNamespace)) {
    Write-Host "Namespace $Namespace does not exist. Creating..." -ForegroundColor Yellow
    kubectl create namespace $Namespace | Out-Host
} else {
    Write-Host "Namespace $Namespace already exists."
}

$enableIstio = [Environment]::GetEnvironmentVariable("ENABLE_ISTIO_INJECTION")
if ($enableIstio -eq "true" -or $enableIstio -eq "True") {
    kubectl label namespace $Namespace istio-injection=enabled --overwrite | Out-Host
}

Deploy-YasConfiguration
Deploy-BackendChart "product" "product"
Deploy-BackendChart "cart" "cart"
Deploy-BackendChart "order" "order"
Deploy-BackendChart "customer" "customer"
Deploy-BackendChart "inventory" "inventory"
Deploy-BackendChart "tax" "tax"
Deploy-BackendChart "media" "media"
Deploy-BackendChart "search" "search"

Deploy-BffChart "storefront-bff" "storefront-bff" "storefront"
Deploy-UiChart "storefront-ui" "storefront-ui"
Deploy-BffChart "backoffice-bff" "backoffice-bff" "backoffice"
Deploy-UiChart "backoffice-ui" "backoffice-ui"

Write-Host "=== Deploy swagger-ui chart ===" -ForegroundColor Green
Build-Dependency "swagger-ui"
$swaggerPath = Test-ChartPath "swagger-ui"
Invoke-Checked "helm upgrade --install swagger-ui `"$swaggerPath`" --namespace $Namespace --create-namespace --set ingress.host=api.$Domain"

foreach ($svc in @("storefront-bff", "storefront-ui", "backoffice-bff", "backoffice-ui", "swagger-ui")) {
    $existingService = kubectl -n $Namespace get svc $svc --ignore-not-found -o name
    if (![string]::IsNullOrWhiteSpace($existingService)) {
        kubectl -n $Namespace patch svc $svc -p '{"spec":{"type":"NodePort"}}' | Out-Host
    } else {
        Write-Host "WARN: service $svc not found; check Helm output." -ForegroundColor Yellow
    }
}

foreach ($deploy in @("product", "cart", "order", "customer", "inventory", "tax", "media", "search", "storefront-bff", "storefront-ui", "backoffice-bff", "backoffice-ui", "swagger-ui")) {
    $existingDeployment = kubectl -n $Namespace get deployment $deploy --ignore-not-found -o name
    if ([string]::IsNullOrWhiteSpace($existingDeployment)) {
        Write-Host "WARN: deployment $deploy not found; skip rollout status." -ForegroundColor Yellow
        continue
    }

    kubectl -n $Namespace rollout status deployment/$deploy --timeout=360s
    if ($LASTEXITCODE -ne 0) { Write-Host "WARN: rollout status failed for $deploy" -ForegroundColor Yellow }
}

Write-Host "=== Pods ===" -ForegroundColor Green
kubectl -n $Namespace get pods -o wide | Out-Host

Write-Host "=== Services ===" -ForegroundColor Green
kubectl -n $Namespace get svc -o wide | Out-Host

& "$PSScriptRoot\Get-AccessUrls.ps1" -Namespace $Namespace -Domain $Domain
