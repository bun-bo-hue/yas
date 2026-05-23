#!/usr/bin/env bash
set -Eeuo pipefail

PROM_NAMESPACE="${PROM_NAMESPACE:-monitoring}"

echo "=== Ensure Helm repositories ==="
helm repo add stakater https://stakater.github.io/stakater-charts --force-update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo update

echo "=== Install Prometheus Operator CRDs for ServiceMonitor resources ==="
helm upgrade --install prometheus-operator-crds prometheus-community/prometheus-operator-crds \
  --namespace "$PROM_NAMESPACE" \
  --create-namespace

kubectl wait --for=condition=Established crd/servicemonitors.monitoring.coreos.com --timeout=180s
kubectl get crd servicemonitors.monitoring.coreos.com
