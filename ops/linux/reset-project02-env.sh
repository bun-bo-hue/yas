#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE_SUFFIX="${NAMESPACE_SUFFIX:-dev01}"
NAMESPACE="yas-${NAMESPACE_SUFFIX}"

echo "=== Deleting Project02 namespaces if they exist ==="
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true || true
kubectl delete namespace yas-dev --ignore-not-found=true || true
kubectl delete namespace yas-dev01 --ignore-not-found=true || true

echo "=== Waiting a little for namespace deletion ==="
sleep 5
kubectl get ns

echo "=== Existing ingresses ==="
kubectl get ingress -A || true
