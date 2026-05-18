param(
    [string]$Namespace = "yas-dev"
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path "evidence" "$Namespace\$timestamp"
New-Item -ItemType Directory -Force $outDir | Out-Null

function Save-Cmd {
    param([string]$Name, [string]$Command)
    $path = Join-Path $outDir $Name
    "# $Command" | Out-File $path -Encoding utf8
    Invoke-Expression $Command 2>&1 | Out-File $path -Encoding utf8 -Append
}

Save-Cmd "nodes.txt" "kubectl get nodes -o wide"
Save-Cmd "namespaces.txt" "kubectl get ns"
Save-Cmd "pods.txt" "kubectl get pods -n $Namespace -o wide"
Save-Cmd "services.txt" "kubectl get svc -n $Namespace -o wide"
Save-Cmd "deployments.txt" "kubectl get deploy -n $Namespace -o wide"
Save-Cmd "ingress.txt" "kubectl get ingress -n $Namespace -o wide"
Save-Cmd "events.txt" "kubectl get events -n $Namespace --sort-by=.lastTimestamp"
Save-Cmd "helm-list.txt" "helm list -n $Namespace"
Save-Cmd "all-observability.txt" "kubectl get pods,svc -A"

Write-Host "Evidence saved to $outDir" -ForegroundColor Green
