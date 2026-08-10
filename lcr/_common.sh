#!/usr/bin/env bash
# Shared helpers for Marketing Digest local container registry (LCR) scripts.
# Prefer the Docker engine that hosts the Kind cluster (system docker), not Docker Desktop.

set -euo pipefail

REGISTRY_NAME="${REGISTRY_NAME:-md-local-registry}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-registry:2}"
REGISTRY_HOST_PORT="${REGISTRY_HOST_PORT:-5001}"
REGISTRY_CONTAINER_PORT="${REGISTRY_CONTAINER_PORT:-5000}"
REGISTRY_VOLUME="${REGISTRY_VOLUME:-md-local-registry-data}"
KIND_NETWORK="${KIND_NETWORK:-kind}"
KIND_CLUSTER="${KIND_CLUSTER:-kind}"
KIND_NODE="${KIND_NODE:-${KIND_CLUSTER}-control-plane}"

# Hostname Kind/containerd uses to reach the registry on the Kind Docker network.
KIND_REGISTRY_HOST="${KIND_REGISTRY_HOST:-md-local-registry}"
KIND_REGISTRY_ENDPOINT="${KIND_REGISTRY_HOST}:${REGISTRY_CONTAINER_PORT}"

# Hostname developers use on the machine to push images.
HOST_REGISTRY_ENDPOINT="localhost:${REGISTRY_HOST_PORT}"

IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-marketing-digest}"
IMAGE_TAG="${IMAGE_TAG:-local}"

SERVICES=(gateway blogs auth)

log() { printf '+ %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Point DOCKER_HOST at the engine that has the Kind network / node.
select_docker_for_kind() {
  if docker network inspect "${KIND_NETWORK}" >/dev/null 2>&1 \
    && docker inspect "${KIND_NODE}" >/dev/null 2>&1; then
    return 0
  fi
  if DOCKER_HOST=unix:///var/run/docker.sock docker network inspect "${KIND_NETWORK}" >/dev/null 2>&1 \
    && DOCKER_HOST=unix:///var/run/docker.sock docker inspect "${KIND_NODE}" >/dev/null 2>&1; then
    export DOCKER_HOST=unix:///var/run/docker.sock
    log "Using Docker engine at ${DOCKER_HOST} (Kind lives here, not Docker Desktop)"
    return 0
  fi
  die "Kind network '${KIND_NETWORK}' / node '${KIND_NODE}' not found in current Docker or system Docker"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed or not on PATH"
}

host_image() {
  local service="$1"
  printf '%s/%s/%s:%s' "${HOST_REGISTRY_ENDPOINT}" "${IMAGE_NAMESPACE}" "${service}" "${IMAGE_TAG}"
}

kind_image() {
  local service="$1"
  printf '%s/%s/%s:%s' "${KIND_REGISTRY_ENDPOINT}" "${IMAGE_NAMESPACE}" "${service}" "${IMAGE_TAG}"
}

# Workspace root containing backend/ and protos/ (parent of md-infra).
workspace_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "$(cd "${here}/../.." && pwd)"
}
