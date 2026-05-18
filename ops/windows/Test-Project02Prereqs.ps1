$ErrorActionPreference = "Continue"

Write-Host "=== Project 02 Windows prerequisites check ==="

function Test-CommandExists {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Write-Host "[MISSING] $Name" -ForegroundColor Red
        return $false
    }
    Write-Host "[OK] $Name -> $($cmd.Source)" -ForegroundColor Green
    return $true
}

$tools = @("git", "docker", "kubectl", "helm", "java")
foreach ($tool in $tools) { Test-CommandExists $tool | Out-Null }

Write-Host ""
Write-Host "=== Versions ==="
try { git --version } catch {}
try { docker --version } catch {}
try { kubectl version --client } catch {}
try { helm version } catch {}
try { java -version } catch {}

Write-Host ""
Write-Host "=== Kubernetes context ==="
try {
    kubectl config current-context
    kubectl get nodes -o wide
} catch {
    Write-Host "Cannot query Kubernetes. Open Docker Desktop and enable Kubernetes." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Docker info ==="
try { docker info --format "Docker server: {{.ServerVersion}}, OSType: {{.OSType}}" } catch {}
