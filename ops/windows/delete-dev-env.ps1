param(
    [string]$Namespace = $env:NAMESPACE,
    [string]$KubeConfig = $env:KUBECONFIG
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Namespace)) { $Namespace = "yas-dev" }
if (Test-Path $KubeConfig) { $env:KUBECONFIG = $KubeConfig }

kubectl config use-context minikube | Out-Host
Write-Host "Deleting namespace $Namespace" -ForegroundColor Yellow
kubectl delete namespace $Namespace --ignore-not-found=true | Out-Host
kubectl get namespace $Namespace 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Namespace $Namespace deleted or not found." -ForegroundColor Green
}
