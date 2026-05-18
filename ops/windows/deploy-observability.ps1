param(
    [string]$KubeConfig = $env:KUBECONFIG
)

$ErrorActionPreference = "Stop"
if (Test-Path $KubeConfig) { $env:KUBECONFIG = $KubeConfig }
kubectl config use-context minikube | Out-Host

Write-Host "=== Deploy YAS Observability ===" -ForegroundColor Green

$obsPath = "k8s\deploy\observability"
if (!(Test-Path $obsPath)) {
    throw "Cannot find $obsPath. Run this from the YAS repository root."
}

# First try the repository manifests/charts directly.
# This is intentionally conservative: if a folder contains Chart.yaml, use Helm; otherwise apply YAML recursively.
Get-ChildItem $obsPath -Directory | ForEach-Object {
    $dir = $_.FullName
    if (Test-Path (Join-Path $dir "Chart.yaml")) {
        $release = $_.Name.ToLower()
        Write-Host "Helm installing $release from $dir" -ForegroundColor Cyan
        helm dependency build $dir
        helm upgrade --install $release $dir --namespace observability --create-namespace
    }
}

$yamlFiles = Get-ChildItem $obsPath -Recurse -Include *.yaml,*.yml -ErrorAction SilentlyContinue
if ($yamlFiles.Count -gt 0) {
    Write-Host "Applying YAML manifests under $obsPath" -ForegroundColor Cyan
    kubectl apply -f $obsPath --recursive
}

Start-Sleep -Seconds 5

# Patch Grafana service to NodePort if present.
$grafanaJson = kubectl get svc -A -o jsonpath='{range .items[?(@.metadata.name=="grafana")]}{.metadata.namespace}{"\n"}{end}' 2>$null
if ($grafanaJson) {
    $ns = ($grafanaJson -split "\r?\n" | Where-Object { $_ -ne "" } | Select-Object -First 1)
    if ($ns) {
        Write-Host "Patching grafana service in namespace $ns to NodePort" -ForegroundColor Cyan
        kubectl -n $ns patch svc grafana -p '{"spec":{"type":"NodePort"}}'
    }
}

Write-Host "=== Observability pods ===" -ForegroundColor Green
kubectl get pods -A | Select-String "grafana|prometheus|loki|tempo|otel|opentelemetry|promtail" | Out-Host
Write-Host "=== Observability services ===" -ForegroundColor Green
kubectl get svc -A | Select-String "grafana|prometheus|loki|tempo" | Out-Host

& "$PSScriptRoot\Get-AccessUrls.ps1" -Namespace yas-dev
