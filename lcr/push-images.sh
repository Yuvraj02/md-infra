#!/usr/bin/env bash
# Build Marketing Digest service images and push them to the local registry.
# Uses existing Dockerfiles only — does not invent Dockerfiles.
#
# Builds from workspace root (parent of backend/ and protos/).
# Pushes via host endpoint localhost:5001; Kubernetes pulls via md-local-registry:5000.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

dockerfile_for() {
  case "$1" in
    gateway) printf 'backend/gateway/Dockerfile' ;;
    blogs)   printf 'backend/services/blog-service/Dockerfile' ;;
    auth)    printf 'backend/services/auth-service/Dockerfile' ;;
    *) die "Unknown service '$1' (expected: gateway|blogs|auth)" ;;
  esac
}

build_and_push() {
  local service="$1"
  local df
  local root
  local host_ref
  local kind_ref

  df="$(dockerfile_for "${service}")"
  root="$(workspace_root)"
  host_ref="$(host_image "${service}")"
  kind_ref="$(kind_image "${service}")"

  if [[ ! -f "${root}/${df}" ]]; then
    die "Dockerfile missing for ${service}: ${root}/${df}"
  fi

  log "Building ${service}"
  log "  Dockerfile : ${df}"
  log "  Context    : ${root}"
  log "  Host tag   : ${host_ref}"
  log "  Kind tag   : ${kind_ref}"

  docker build \
    -f "${root}/${df}" \
    -t "${host_ref}" \
    -t "${kind_ref}" \
    "${root}"

  log "Pushing ${host_ref} (same registry content as ${kind_ref})"
  docker push "${host_ref}"
}

main() {
  require_cmd docker
  require_cmd curl
  select_docker_for_kind

  if ! docker inspect "${REGISTRY_NAME}" >/dev/null 2>&1; then
    die "Registry '${REGISTRY_NAME}' not found — run ./lcr/setup.sh first"
  fi
  if ! curl -fsS "http://${HOST_REGISTRY_ENDPOINT}/v2/" >/dev/null 2>&1; then
    die "Registry API not reachable at http://${HOST_REGISTRY_ENDPOINT}/v2/ — run ./lcr/setup.sh"
  fi

  local targets=("${SERVICES[@]}")
  if [[ "$#" -gt 0 ]]; then
    targets=("$@")
  fi

  local svc
  for svc in "${targets[@]}"; do
    build_and_push "${svc}"
  done

  log "Done. Kind/Kubernetes image references:"
  for svc in "${targets[@]}"; do
    printf '  %s\n' "$(kind_image "${svc}")"
  done
}

main "$@"
