#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE_SUFFIX="${NAMESPACE_SUFFIX:-dev01}"
NAMESPACE="${NAMESPACE:-yas-${NAMESPACE_SUFFIX}}"
OUT_DIR="${OUT_DIR:-evidence/$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT_DIR"

echo "Collecting evidence into $OUT_DIR"
{
  echo "# Project02 Evidence"
  echo "Generated at: $(date)"
  echo "Namespace: $NAMESPACE"
  echo
  echo "## Current context"
  kubectl config current-context || true
  echo
  echo "## Nodes"
  kubectl get nodes -o wide || true
  echo
  echo "## Namespaces"
  kubectl get ns || true
  echo
  echo "## Pods"
  kubectl get pods -n "$NAMESPACE" -o wide || true
  echo
  echo "## Services"
  kubectl get svc -n "$NAMESPACE" || true
  echo
  echo "## Ingress"
  kubectl get ingress -n "$NAMESPACE" || true
  echo
  echo "## Helm releases"
  helm list -n "$NAMESPACE" || true
  echo
  echo "## Recent events"
  kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp || true
} | tee "$OUT_DIR/cluster-evidence.txt"

kubectl get pods -n "$NAMESPACE" -o yaml > "$OUT_DIR/pods.yaml" 2>/dev/null || true
kubectl get svc -n "$NAMESPACE" -o yaml > "$OUT_DIR/services.yaml" 2>/dev/null || true
kubectl get ingress -n "$NAMESPACE" -o yaml > "$OUT_DIR/ingress.yaml" 2>/dev/null || true

echo "Evidence collected: $OUT_DIR"
