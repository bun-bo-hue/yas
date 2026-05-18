$ErrorActionPreference = "Continue"

function Test-Cmd($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { Write-Host "[OK] $name -> $($cmd.Source)" -ForegroundColor Green }
    else { Write-Host "[MISSING] $name" -ForegroundColor Red }
}

Write-Host "=== Checking tools ===" -ForegroundColor Cyan
foreach ($c in @('git','docker','kubectl','helm','minikube','java','javac')) { Test-Cmd $c }

Write-Host "\n=== Versions ===" -ForegroundColor Cyan
git --version
docker --version
kubectl version --client
helm version
minikube version
java --version
javac --version

Write-Host "\n=== Kubernetes context ===" -ForegroundColor Cyan
kubectl config get-contexts
kubectl config use-context minikube
kubectl get nodes -o wide

Write-Host "\n=== Minikube status ===" -ForegroundColor Cyan
minikube status
