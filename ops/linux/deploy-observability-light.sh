#!/usr/bin/env bash
set -Eeuo pipefail

# Lightweight observability access for Project02 evidence.
# This installs kube-prometheus-stack so Grafana/Prometheus are accessible.
# Run after core app deploy if the PC still has enough RAM.

OBS_NAMESPACE="${OBS_NAMESPACE:-monitoring}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "$OBS_NAMESPACE" \
  --create-namespace \
  --set grafana.adminPassword="$GRAFANA_PASSWORD" \
  --set grafana.service.type=NodePort \
  --set prometheus.service.type=NodePort \
  --set alertmanager.enabled=false

kubectl -n "$OBS_NAMESPACE" rollout status deployment/kube-prometheus-stack-grafana --timeout=300s || true
kubectl -n "$OBS_NAMESPACE" get pods,svc

echo "Grafana URL:"
minikube service kube-prometheus-stack-grafana -n "$OBS_NAMESPACE" --url || true
echo "Login: admin / ${GRAFANA_PASSWORD}"
