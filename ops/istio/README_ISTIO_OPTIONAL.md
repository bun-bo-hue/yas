# Optional Service Mesh Evidence

Only run this after the normal YAS core deployment is stable.

```bash
istioctl install --set profile=demo -y
kubectl label namespace yas-dev01 istio-injection=enabled --overwrite
kubectl rollout restart deployment -n yas-dev01
kubectl apply -f ops/istio/01-peer-authentication-strict-mtls.yaml
kubectl apply -f ops/istio/02-destinationrule-default-mtls.yaml
kubectl apply -f ops/istio/03-virtualservice-tax-retry.yaml
kubectl apply -f ops/istio/04-authorizationpolicy-tax-only-order.yaml
```

For Kiali topology:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/kiali.yaml
istioctl dashboard kiali
```

Screenshots to capture:

1. Namespace with Istio injection enabled.
2. Kiali graph showing YAS service calls.
3. YAML manifests for mTLS, retry, and AuthorizationPolicy.
4. Curl test from allowed and non-allowed pods.
