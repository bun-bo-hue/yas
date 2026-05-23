#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Project02 prerequisite check ==="
required=(git docker kubectl minikube helm java)
missing=0
for cmd in "${required[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "[OK] %-10s %s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "[MISSING] %s\n" "$cmd"
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "One or more tools are missing. Install them before continuing."
  exit 1
fi

echo
echo "=== Versions ==="
git --version || true
docker --version || true
kubectl version --client || true
minikube version || true
helm version || true
java -version || true

echo
echo "=== Docker connectivity ==="
docker info >/dev/null
echo "Docker is reachable."

echo
echo "=== Current Kubernetes context ==="
kubectl config current-context || true

echo
echo "Prerequisite check completed."
