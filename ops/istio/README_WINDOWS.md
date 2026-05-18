# Service Mesh demo - Windows commands

Use this only after the normal Jenkins CD + Observability flow works.

```powershell
istioctl install --set profile=demo -y
kubectl label namespace yas-dev istio-injection=enabled --overwrite
kubectl rollout restart deployment -n yas-dev
```

Apply policies:

```powershell
kubectl apply -f .\ops\istio\
```

If you deploy to another namespace, replace `yas-dev` first:

```powershell
(Get-Content .\ops\istio\01-peer-authentication-strict-mtls.yaml) -replace "yas-dev", "yas-mesh" | kubectl apply -f -
```

Open Kiali:

```powershell
kubectl port-forward svc/kiali -n istio-system 20001:20001
```

Then open `http://localhost:20001`.
