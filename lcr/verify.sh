#!/usr/bin/env bash
# Verify the local registry is running, contains expected tags, and Kind can pull.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

fail=0
ok() { printf 'OK  %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*" >&2; fail=1; }

main() {
  require_cmd docker
  require_cmd curl
  select_docker_for_kind

  if docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null | grep -qx true; then
    ok "Registry container ${REGISTRY_NAME} is running"
  else
    bad "Registry container ${REGISTRY_NAME} is not running"
  fi

  if curl -fsS "http://${HOST_REGISTRY_ENDPOINT}/v2/" >/dev/null 2>&1; then
    ok "Registry HTTP API reachable at http://${HOST_REGISTRY_ENDPOINT}/v2/"
  else
    bad "Registry HTTP API not reachable at http://${HOST_REGISTRY_ENDPOINT}/v2/"
  fi

  local catalog
  catalog="$(curl -fsS "http://${HOST_REGISTRY_ENDPOINT}/v2/_catalog" 2>/dev/null || true)"
  if [[ -n "${catalog}" ]]; then
    ok "Registry catalog: ${catalog}"
  else
    bad "Could not read /v2/_catalog"
  fi

  local svc repo tags
  for svc in "${SERVICES[@]}"; do
    repo="${IMAGE_NAMESPACE}/${svc}"
    tags="$(curl -fsS "http://${HOST_REGISTRY_ENDPOINT}/v2/${repo}/tags/list" 2>/dev/null || true)"
    if printf '%s' "${tags}" | grep -q "\"${IMAGE_TAG}\""; then
      ok "Tag present: ${repo}:${IMAGE_TAG} (${tags})"
    else
      bad "Missing tag ${repo}:${IMAGE_TAG} (got: ${tags:-none}) — run ./lcr/push-images.sh"
    fi
  done

  if docker exec "${KIND_NODE}" getent hosts "${KIND_REGISTRY_HOST}" >/dev/null 2>&1 \
    || docker exec "${KIND_NODE}" nslookup "${KIND_REGISTRY_HOST}" >/dev/null 2>&1; then
    ok "Kind node resolves ${KIND_REGISTRY_HOST}"
  else
    # Docker embedded DNS often still works for pulls even if getent is limited.
    bad "Kind node could not resolve ${KIND_REGISTRY_HOST} (is registry on network '${KIND_NETWORK}'?)"
  fi

  if docker exec "${KIND_NODE}" curl -fsS "http://${KIND_REGISTRY_ENDPOINT}/v2/" >/dev/null 2>&1; then
    ok "Kind node can reach registry HTTP API at http://${KIND_REGISTRY_ENDPOINT}/v2/"
  else
    bad "Kind node cannot reach http://${KIND_REGISTRY_ENDPOINT}/v2/"
  fi

  local sample
  sample="$(kind_image gateway)"
  log "Attempting containerd pull of ${sample} inside Kind node"
  if docker exec "${KIND_NODE}" ctr -n k8s.io images pull --plain-http "${sample}" >/dev/null 2>&1 \
    || docker exec "${KIND_NODE}" crictl pull "${sample}" >/dev/null 2>&1; then
    ok "Kind pulled ${sample}"
  else
    bad "Kind failed to pull ${sample}"
  fi

  if [[ "${fail}" -ne 0 ]]; then
    die "Verification failed"
  fi
  log "All registry checks passed"
}

main "$@"
