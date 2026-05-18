param(
    [int]$Cpus = 6,
    [string]$Memory = "12288mb",
    [string]$DiskSize = "80g",
    [string]$Driver = "docker"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Starting Minikube ===" -ForegroundColor Green
Write-Host "Driver: $Driver | CPUs: $Cpus | Memory: $Memory | Disk: $DiskSize"

minikube start --driver=$Driver --cpus=$Cpus --memory=$Memory --disk-size=$DiskSize
if ($LASTEXITCODE -ne 0) { throw "minikube start failed" }

kubectl config use-context minikube | Out-Host
kubectl get nodes -o wide | Out-Host

Write-Host "=== Recommended addons ===" -ForegroundColor Green
minikube addons enable metrics-server | Out-Host
minikube addons enable ingress | Out-Host

Write-Host "=== Minikube IP ===" -ForegroundColor Green
minikube ip | Out-Host

Write-Host "Minikube is ready when node status is Ready." -ForegroundColor Green
