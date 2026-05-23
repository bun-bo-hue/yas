#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE_SUFFIX="${NAMESPACE_SUFFIX:-dev01}"
NAMESPACE="${NAMESPACE:-yas-${NAMESPACE_SUFFIX}}"
DOMAIN_ROOT="${DOMAIN_ROOT:-yas.local.com}"
APP_DOMAIN="${APP_DOMAIN:-${NAMESPACE_SUFFIX}.${DOMAIN_ROOT}}"
MINIKUBE_IP="$(minikube ip)"

cat <<EOF
=== Hosts records ===
Add these to Windows hosts file as Administrator:
${MINIKUBE_IP} storefront.${APP_DOMAIN}
${MINIKUBE_IP} backoffice.${APP_DOMAIN}
${MINIKUBE_IP} api.${APP_DOMAIN}

=== Ingress URLs ===
http://storefront.${APP_DOMAIN}/
http://backoffice.${APP_DOMAIN}/
http://api.${APP_DOMAIN}/swagger-ui

=== NodePort service URLs ===
EOF
minikube service storefront-bff -n "$NAMESPACE" --url || true
minikube service backoffice-bff -n "$NAMESPACE" --url || true
minikube service swagger-ui -n "$NAMESPACE" --url || true
