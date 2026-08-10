# md-infra

GitOps and cluster infrastructure for **Marketing Digest**.

## Purpose

`md-infra` owns how the cluster is configured and how applications are
declared to Argo CD. It does **not** own application source code, Helm
chart templates, or environment-specific Helm values.

## Layout

```text
argocd/
  bootstrap/              # Root Application (GitOps entrypoint)
  applicationsets/
    gateway/{local,prod}/ # gateway ApplicationSets
    blogs/{local,prod}/   # blogs ApplicationSets
    auth/{local,prod}/    # auth ApplicationSets
  addons/                 # Future cluster addons
lcr/                      # Local Container Registry helpers (NOT Argo CD)
terraform/                # Future AWS / platform infrastructure (placeholder)
```

### `argocd/bootstrap`

Root Argo CD `Application` watches this repository (`path: argocd`, with
`directory.recurse: true`) so nested ApplicationSets under
`applicationsets/` are synced into the `argocd` namespace.

Apply once (bootstrap chicken-and-egg):

```bash
kubectl apply -f argocd/bootstrap/root-application.yaml
```

After that, Git is the source of truth — including updates to this root
Application itself.

### `argocd/applicationsets`

One ApplicationSet per service/environment. Each generates exactly one
Argo CD Application that multi-sources:

- Helm chart from [md-charts](https://github.com/Yuvraj02/md-charts.git)
- Values from [md-helm-values](https://github.com/Yuvraj02/md-helm-values.git)

Local apps deploy to namespace `marketing-digest` on
`https://kubernetes.default.svc` (Kind).

Production apps use Argo CD cluster destination `name: production`
(placeholder until EKS is registered). Do not invent an EKS API URL.

### Sync policy

Local and production ApplicationSets use automated sync with `prune` and
`selfHeal` so Argo CD restores accidentally deleted Deployments/Services.
Production still needs a real cluster destination before it can sync.

## Secrets

Secrets are **not** stored in Git. Create Kubernetes Secrets manually;
charts/values may only reference them by name.

## Related repositories

| Repository | Owns |
|---|---|
| [md-infra](https://github.com/Yuvraj02/md-infra.git) | Argo CD (this repo) |
| [md-charts](https://github.com/Yuvraj02/md-charts.git) | Per-service Helm charts |
| [md-helm-values](https://github.com/Yuvraj02/md-helm-values.git) | Per-service environment values |
