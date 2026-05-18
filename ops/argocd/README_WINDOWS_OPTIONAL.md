# Optional ArgoCD direction for advanced marks

This kit focuses on the required Windows-only GitHub Actions + Jenkins CD flow first.

If the team has time, add ArgoCD later with this layout in the fork:

```text
gitops/
  dev/
    values-dev.yaml
  staging/
    values-staging.yaml
```

Recommended Applications:

- `yas-dev`: watches `gitops/dev`, auto-sync enabled, namespace `yas-dev`.
- `yas-staging`: watches `gitops/staging`, syncs release tag or release branch, namespace `yas-staging`.

Do not start with ArgoCD. Finish `developer_build`, `developer_delete`, NodePort demo, and Observability first.
