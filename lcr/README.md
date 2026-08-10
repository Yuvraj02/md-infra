# Local Container Registry (LCR)

Runtime helpers for a **local Docker Registry** used by the Kind cluster.

This is **not** an Argo CD application. Nothing under `lcr/` is synced by Argo CD.

## What a container registry is

A registry is an **HTTP server** that stores image manifests and layers.

- `docker build` creates an image in the local Docker engine.
- `docker push` uploads that image **to the registry server** over HTTP.
- Images are **not** copied as running containers into the registry.
- Kubernetes/containerd later **pulls** the same image from the registry when creating Pods.

```text
Developer
   |
   | docker build
   v
Docker image (local engine)
   |
   | docker push  →  localhost:5001
   v
md-local-registry (registry:2 server)
   |
   | containerd pull  ←  md-local-registry:5000
   v
Kind node
   |
   v
Pod
```

Production maps the same pattern to ECR + EKS:

```text
Jenkins/docker build → docker push → AWS ECR → EKS containerd pull → Pod
```

## Endpoints

| Who | Endpoint | Purpose |
|-----|----------|---------|
| Host (developer) | `localhost:5001` | `docker push` / registry API |
| Kind / Kubernetes | `md-local-registry:5000` | `containerd` pull / Pod `image:` |

Both reach the **same** registry container. Do **not** put `localhost:5001` in Pod specs — inside a Kind node, `localhost` is the node itself, not your laptop.

## Image names (local)

```text
md-local-registry:5000/marketing-digest/gateway:local
md-local-registry:5000/marketing-digest/blogs:local
md-local-registry:5000/marketing-digest/auth:local
```

Host push tags use the same repository path via `localhost:5001/...`.

## Helm does not pull images

`md-helm-values` only configures Deployments:

```yaml
image:
  repository: md-local-registry:5000/marketing-digest/gateway
  tag: local
```

Helm renders `image: md-local-registry:5000/marketing-digest/gateway:local`.  
**containerd** performs the pull when the Pod starts.

```text
Helm values → Helm render → Deployment → Pod → containerd → md-local-registry:5000
```

## Scripts

Use the Docker engine that hosts Kind (on this machine: system Docker at
`unix:///var/run/docker.sock`, not Docker Desktop). The scripts auto-select it.

```bash
cd md-infra/lcr
./setup.sh          # create/connect registry + Kind insecure HTTP config
./push-images.sh    # build+push gateway blogs auth (or pass a subset)
./verify.sh         # API catalog/tags + Kind pull smoke test
```

### Dockerfiles (existing)

Build context = workspace root (parent of `backend/` and `protos/`):

| Service | Dockerfile |
|---------|------------|
| gateway | `backend/gateway/Dockerfile` |
| blogs   | `backend/services/blog-service/Dockerfile` |
| auth    | `backend/services/auth-service/Dockerfile` |

## Kind networking

`setup.sh` attaches `md-local-registry` to the Docker network `kind` and writes
containerd `hosts.toml` for plain HTTP pulls (`md-local-registry:5000`).

It does **not** delete or recreate the Kind cluster.

## Secrets

No secrets are stored in these scripts or in Helm values for the registry.
