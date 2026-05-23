#!/usr/bin/env bash
set -Eeuo pipefail

# Project02 YAS core deploy script for WSL2/Ubuntu + Minikube.
# It intentionally deploys the service set from deployment-services.pdf and skips
# payment, payment-paypal, debezium-connect, promotion, rating, recommendation,
# sampledata, webhook, and location.

NAMESPACE_SUFFIX="${NAMESPACE_SUFFIX:-dev01}"
NAMESPACE="${NAMESPACE:-yas-${NAMESPACE_SUFFIX}}"
DOCKERHUB_USER="${DOCKERHUB_USER:?Set DOCKERHUB_USER first, for example: export DOCKERHUB_USER=juzharii}"
DOMAIN_ROOT="${DOMAIN_ROOT:-yas.local.com}"
APP_DOMAIN="${APP_DOMAIN:-${NAMESPACE_SUFFIX}.${DOMAIN_ROOT}}"
ENABLE_ISTIO_INJECTION="${ENABLE_ISTIO_INJECTION:-false}"
STRICT_ROLLOUT="${STRICT_ROLLOUT:-true}"

STORE_HOST="storefront.${APP_DOMAIN}"
BACKOFFICE_HOST="backoffice.${APP_DOMAIN}"
API_HOST="api.${APP_DOMAIN}"
MINIKUBE_IP="$(minikube ip 2>/dev/null || true)"

# Default tags. Non-main branch tags are resolved by Jenkins into full commit SHA.
TAG_PRODUCT="${TAG_PRODUCT:-main}"
TAG_CART="${TAG_CART:-main}"
TAG_ORDER="${TAG_ORDER:-main}"
TAG_CUSTOMER="${TAG_CUSTOMER:-main}"
TAG_INVENTORY="${TAG_INVENTORY:-main}"
TAG_TAX="${TAG_TAX:-main}"
TAG_MEDIA="${TAG_MEDIA:-main}"
TAG_SEARCH="${TAG_SEARCH:-main}"
TAG_STOREFRONT_BFF="${TAG_STOREFRONT_BFF:-main}"
TAG_BACKOFFICE_BFF="${TAG_BACKOFFICE_BFF:-main}"
TAG_STOREFRONT="${TAG_STOREFRONT:-${TAG_STOREFRONT_UI:-main}}"
TAG_BACKOFFICE="${TAG_BACKOFFICE:-${TAG_BACKOFFICE_UI:-main}}"

run() {
  echo "> $*"
  "$@"
}

require_chart() {
  local chart="$1"
  local path="k8s/charts/${chart}"
  if [[ ! -d "$path" ]]; then
    echo "ERROR: chart path not found: $path"
    echo "Run this script from the YAS repository root."
    exit 1
  fi
}

helm_dep_build() {
  local chart="$1"
  require_chart "$chart"
  run helm dependency build "k8s/charts/${chart}"
}

ensure_context() {
  run kubectl config use-context minikube
  run kubectl get nodes
}

ensure_namespace() {
  echo "=== Namespace: ${NAMESPACE} ==="
  if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    run kubectl create namespace "$NAMESPACE"
  else
    echo "Namespace ${NAMESPACE} already exists."
  fi

  if [[ "$ENABLE_ISTIO_INJECTION" == "true" ]]; then
    run kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite
  fi
}

ensure_helm_repos_and_crds() {
  echo "=== Helm repositories and CRDs ==="
  run helm repo add stakater https://stakater.github.io/stakater-charts --force-update
  run helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
  run helm repo update

  if ! kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    run helm upgrade --install prometheus-operator-crds prometheus-community/prometheus-operator-crds \
      --namespace monitoring \
      --create-namespace
    run kubectl wait --for=condition=Established crd/servicemonitors.monitoring.coreos.com --timeout=180s
  else
    echo "ServiceMonitor CRD already exists."
  fi
}

deploy_yas_configuration() {
  echo "=== Deploy YAS shared configuration ==="
  helm_dep_build yas-configuration
  run helm upgrade --install yas-configuration "k8s/charts/yas-configuration" \
    --namespace "$NAMESPACE" \
    --create-namespace

  echo "=== Verify shared ConfigMaps and Secrets ==="
  run kubectl -n "$NAMESPACE" get configmap yas-configuration-configmap
  run kubectl -n "$NAMESPACE" get secret yas-postgresql-credentials-secret
}

deploy_backend() {
  local release="$1"
  local image_name="$2"
  local tag="$3"
  local chart="$release"

  echo "=== Deploy backend ${release} -> docker.io/${DOCKERHUB_USER}/yas-${image_name}:${tag} ==="
  helm_dep_build "$chart"

  run helm upgrade --install "$release" "k8s/charts/${chart}" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --set "backend.image.repository=docker.io/${DOCKERHUB_USER}/yas-${image_name}" \
    --set "backend.image.tag=${tag}" \
    --set "backend.ingress.enabled=false" \
    --set "backend.service.type=ClusterIP"
}

deploy_bff() {
  local release="$1"
  local image_name="$2"
  local tag="$3"
  local host="$4"
  local chart="$release"

  echo "=== Deploy BFF ${release} -> docker.io/${DOCKERHUB_USER}/yas-${image_name}:${tag} ==="
  helm_dep_build "$chart"

  run helm upgrade --install "$release" "k8s/charts/${chart}" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --set "backend.image.repository=docker.io/${DOCKERHUB_USER}/yas-${image_name}" \
    --set "backend.image.tag=${tag}" \
    --set "backend.ingress.enabled=true" \
    --set "backend.ingress.host=${host}" \
    --set "backend.service.type=ClusterIP"
}

deploy_ui() {
  local release="$1"
  local image_name="$2"
  local tag="$3"
  local chart="$release"

  echo "=== Deploy UI ${release} -> docker.io/${DOCKERHUB_USER}/yas-${image_name}:${tag} ==="
  helm_dep_build "$chart"

  run helm upgrade --install "$release" "k8s/charts/${chart}" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --set "ui.image.repository=docker.io/${DOCKERHUB_USER}/yas-${image_name}" \
    --set "ui.image.tag=${tag}" \
    --set "ui.ingress.enabled=false" \
    --set "ui.service.type=ClusterIP"
}

deploy_swagger() {
  echo "=== Deploy swagger-ui ==="
  helm_dep_build swagger-ui
  run helm upgrade --install swagger-ui "k8s/charts/swagger-ui" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --set "ingress.enabled=true" \
    --set "ingress.host=${API_HOST}" \
    --set "ingress.hosts[0].host=${API_HOST}" \
    --set "service.type=ClusterIP"
}

patch_nodeport() {
  local svc="$1"
  if ! kubectl -n "$NAMESPACE" get svc "$svc" >/dev/null 2>&1; then
    echo "WARN: service ${svc} not found. Skip NodePort patch."
    return 0
  fi
  echo "=== Patch service ${svc} to NodePort ==="
  kubectl -n "$NAMESPACE" patch svc "$svc" --type=merge -p '{"spec":{"type":"NodePort"}}'
}

wait_rollouts() {
  echo "=== Rollout status ==="
  local deployments=(
    product cart order customer inventory tax media search
    storefront-ui storefront-bff backoffice-ui backoffice-bff swagger-ui
  )
  local failed=()
  for deploy in "${deployments[@]}"; do
    if kubectl -n "$NAMESPACE" get deployment "$deploy" >/dev/null 2>&1; then
      echo "Waiting for deployment/${deploy} ..."
      if ! kubectl -n "$NAMESPACE" rollout status "deployment/${deploy}" --timeout=480s; then
        echo "ERROR: rollout failed for ${deploy}"
        failed+=("$deploy")
      fi
    else
      echo "WARN: deployment/${deploy} not found"
      failed+=("$deploy-not-found")
    fi
  done

  echo "=== Pods ==="
  kubectl -n "$NAMESPACE" get pods -o wide || true
  echo "=== Services ==="
  kubectl -n "$NAMESPACE" get svc || true
  echo "=== Ingress ==="
  kubectl -n "$NAMESPACE" get ingress || true

  if [[ ${#failed[@]} -gt 0 && "$STRICT_ROLLOUT" == "true" ]]; then
    echo "=== Recent events ==="
    kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp | tail -n 80 || true
    echo "Rollout failed for: ${failed[*]}"
    exit 1
  fi
}

print_access_info() {
  echo "=== Access information ==="
  echo "Namespace:       ${NAMESPACE}"
  echo "Minikube IP:     ${MINIKUBE_IP}"
  echo "Storefront host: http://${STORE_HOST}/"
  echo "Backoffice host: http://${BACKOFFICE_HOST}/"
  echo "Swagger host:    http://${API_HOST}/swagger-ui"
  echo
  echo "Add these records to Windows hosts file if you use Ingress:"
  echo "${MINIKUBE_IP} ${STORE_HOST}"
  echo "${MINIKUBE_IP} ${BACKOFFICE_HOST}"
  echo "${MINIKUBE_IP} ${API_HOST}"
  echo
  echo "NodePort URLs, if Minikube can expose them:"
  minikube service storefront-bff -n "$NAMESPACE" --url || true
  minikube service backoffice-bff -n "$NAMESPACE" --url || true
  minikube service swagger-ui -n "$NAMESPACE" --url || true
}

main() {
  echo "=== Project02 YAS core deployment ==="
  echo "Namespace:       ${NAMESPACE}"
  echo "Docker Hub user: ${DOCKERHUB_USER}"
  echo "App domain:      ${APP_DOMAIN}"
  echo "Storefront host: ${STORE_HOST}"
  echo "Backoffice host: ${BACKOFFICE_HOST}"
  echo "API host:        ${API_HOST}"

  ensure_context
  ensure_helm_repos_and_crds
  ensure_namespace
  deploy_yas_configuration

  # Backends kept for the assignment demo.
  deploy_backend product product "$TAG_PRODUCT"
  deploy_backend cart cart "$TAG_CART"
  deploy_backend order order "$TAG_ORDER"
  deploy_backend customer customer "$TAG_CUSTOMER"
  deploy_backend inventory inventory "$TAG_INVENTORY"
  deploy_backend tax tax "$TAG_TAX"
  deploy_backend media media "$TAG_MEDIA"
  deploy_backend search search "$TAG_SEARCH"

  # UI charts use official chart-compatible image names: yas-storefront and yas-backoffice.
  deploy_ui storefront-ui storefront "$TAG_STOREFRONT"
  deploy_ui backoffice-ui backoffice "$TAG_BACKOFFICE"

  # BFFs are the browser-facing entry points in YAS.
  deploy_bff storefront-bff storefront-bff "$TAG_STOREFRONT_BFF" "$STORE_HOST"
  deploy_bff backoffice-bff backoffice-bff "$TAG_BACKOFFICE_BFF" "$BACKOFFICE_HOST"

  deploy_swagger

  # Patch selected services to NodePort so the deliverable can show domain/IP + port.
  patch_nodeport storefront-bff
  patch_nodeport backoffice-bff
  patch_nodeport swagger-ui

  wait_rollouts
  print_access_info
}

main "$@"
