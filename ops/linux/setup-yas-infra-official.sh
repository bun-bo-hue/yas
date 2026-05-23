#!/usr/bin/env bash
set -Eeuo pipefail

# Wrapper around the official YAS k8s/deploy scripts.
# Run this from the YAS repository root after Minikube is ready.

if [[ ! -d "k8s/deploy" ]]; then
  echo "ERROR: k8s/deploy not found. Run from YAS repository root."
  exit 1
fi

kubectl config use-context minikube
kubectl get nodes

chmod +x k8s/deploy/*.sh || true

# Official docs enable ingress before infrastructure.
minikube addons enable ingress || true
minikube addons enable storage-provisioner || true
minikube addons enable default-storageclass || true

pushd k8s/deploy >/dev/null

echo "=== Setup Keycloak ==="
./setup-keycloak.sh

echo "=== Setup Redis ==="
./setup-redis.sh

echo "=== Setup core cluster dependencies: Postgres, Elasticsearch, Kafka, etc. ==="
./setup-cluster.sh

popd >/dev/null

echo "=== Optional cleanup: disable Debezium Connect if it exists and is unstable ==="
for ns in kafka debezium default; do
  if kubectl get deployment -n "$ns" debezium-connect >/dev/null 2>&1; then
    kubectl -n "$ns" scale deployment/debezium-connect --replicas=0 || true
  fi
done

echo "=== Infrastructure status ==="
kubectl get pods -A
