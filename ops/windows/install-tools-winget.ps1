$ErrorActionPreference = "Stop"

Write-Host "Installing Project02 tools for Windows + Minikube..." -ForegroundColor Green
winget install Git.Git --accept-source-agreements --accept-package-agreements
winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
winget install Kubernetes.kubectl --accept-source-agreements --accept-package-agreements
winget install Helm.Helm --accept-source-agreements --accept-package-agreements
winget install Kubernetes.minikube --accept-source-agreements --accept-package-agreements
winget install EclipseAdoptium.Temurin.25.JDK --accept-source-agreements --accept-package-agreements
winget install Jenkins.Jenkins --accept-source-agreements --accept-package-agreements

Write-Host "Done. Close and reopen PowerShell, then run ops\windows\Test-Project02Prereqs.ps1" -ForegroundColor Green
