# md-infra

GitOps and cluster infrastructure for **Marketing Digest**.

## Purpose

`md-infra` owns how the cluster is configured and how applications are
declared to Argo CD. It does **not** own application source code, Helm
chart templates, or environment-specific Helm values.

## Why Argo CD config lives here

Argo CD Applications and ApplicationSets are cluster control-plane config.
Keeping them in `md-infra` separates:

- **what to deploy and from where** (this repo)
- **how Kubernetes objects are templated** (`md-charts`)
- **environment-specific non-secret values** (`md-helm-values`)

## Layout

```text
argocd/
  bootstrap/         # Root Application (GitOps entrypoint)
  applicationsets/   # Future ApplicationSets (frontend, gateway, blogs, auth)
  addons/            # Future cluster addons managed by Argo CD
terraform/           # Future AWS / platform infrastructure (placeholder)
```

### `argocd/bootstrap`

Contains the root Argo CD `Application` that points Argo CD at this
repository so Git becomes the source of truth for Argo CD config.

### `argocd/applicationsets`

Will eventually hold ApplicationSets that generate per-service Applications
(frontend, gateway, blogs, auth). Not implemented yet.

### `argocd/addons`

Will eventually hold Argo CD Applications for cluster addons (ingress,
observability, etc.). Not implemented yet.

### `terraform/`

Placeholder for future AWS infrastructure (for example networking and
managed services). No Terraform is defined yet.

## Related repositories

| Repository | Owns |
|---|---|
| [md-infra](https://github.com/Yuvraj02/md-infra.git) | Argo CD bootstrap, Applications, ApplicationSets, addons, Terraform |
| [md-charts](https://github.com/Yuvraj02/md-charts.git) | Helm charts / templates / chart versions |
| [md-helm-values](https://github.com/Yuvraj02/md-helm-values.git) | Environment values (local / staging / production), image tags, replicas, resources |

## GitOps architecture (current → future)

**Now**

```text
GitHub md-infra
      |
      v
root Application (argocd/bootstrap)
      |
      v
Argo CD
      |
      v
md-infra Git repository (branch: main)
```

**Later**

```text
md-infra (ApplicationSet)
    |
    +-- frontend / gateway / blogs / auth Applications
            |
            +-- chart from md-charts
            +-- values from md-helm-values
                    |
                    v
                  Helm → Kubernetes → Marketing Digest
```

## Secrets

Secrets are **not** stored in Git.

Do not put credentials, tokens, database passwords, `OWNER_STUDIO_SECRET`,
or private keys in `md-infra`, `md-charts`, or `md-helm-values`.

Secrets will be created manually later as Kubernetes `Secret` objects.
Charts should reference existing Secrets by name when needed.
