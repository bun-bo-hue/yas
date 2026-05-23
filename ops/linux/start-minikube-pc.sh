#!/usr/bin/env bash
set -Eeuo pipefail

CPUS="${CPUS:-6}"
MEMORY="${MEMORY:-16384}"
DISK_SIZE="${DISK_SIZE:-60000mb}"
K8S_VERSION="${K8S_VERSION:-v1.32.0}"
DRIVER="${DRIVER:-docker}"

cat <<EOF
=== Starting Minikube for Project02 ===
Driver:          $DRIVER
Kubernetes:      $K8S_VERSION
CPU:             $CPUS
Memory:          ${MEMORY}MB
Disk:            $DISK_SIZE
EOF

minikube start \
  --driver="$DRIVER" \
  --kubernetes-version="$K8S_VERSION" \
  --cpus="$CPUS" \
  --memory="$MEMORY" \
  --disk-size="$DISK_SIZE" \
  --wait=all \
  --wait-timeout=10m

minikube update-context
kubectl config use-context minikube

echo "=== Enabling useful Minikube addons ==="
minikube addons enable ingress || true
minikube addons enable storage-provisioner || true
minikube addons enable default-storageclass || true

echo "=== Cluster check ==="
kubectl get nodes -o wide
kubectl get pods -A

echo "=== Minikube IP ==="
minikube ip
