#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE_SUFFIX="${NAMESPACE_SUFFIX:-dev01}"
NAMESPACE="${NAMESPACE:-yas-${NAMESPACE_SUFFIX}}"

echo "Deleting namespace: $NAMESPACE"
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

echo "Remaining namespaces:"
kubectl get ns
