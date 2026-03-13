#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/cleanup-namespaces.sh [--wait] [--timeout SECONDS]

Deletes namespaces used by this project:
  - ci-assignment
  - ci-assignment-monitoring

Also deletes cluster-scoped storage resource used by Postgres:
  - PersistentVolume/postgres-pv-local

Options:
  --wait               Wait for namespaces to be fully deleted
  --timeout SECONDS    Max wait time when --wait is used (default: 300)
  -h, --help           Show this help message
EOF
}

WAIT_FOR_DELETION=false
TIMEOUT_SECONDS=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_FOR_DELETION=true
      shift
      ;;
    --timeout)
      if [[ -z "${2:-}" || ! "${2}" =~ ^[0-9]+$ ]]; then
        echo "Error: --timeout requires a numeric value in seconds." >&2
        exit 1
      fi
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH" >&2
    exit 1
  fi
}

namespace_exists() {
  local ns="$1"
  kubectl get namespace "$ns" >/dev/null 2>&1
}

pv_exists() {
  local pv="$1"
  kubectl get pv "$pv" >/dev/null 2>&1
}

require_cmd kubectl

NAMESPACES=("ci-assignment" "ci-assignment-monitoring")
POSTGRES_PV="postgres-pv-local"

for ns in "${NAMESPACES[@]}"; do
  if namespace_exists "$ns"; then
    echo "Deleting namespace: $ns"
    kubectl delete namespace "$ns" --wait=false
  else
    echo "Namespace already absent: $ns"
  fi
done

if pv_exists "$POSTGRES_PV"; then
  echo "Deleting persistent volume: $POSTGRES_PV"
  kubectl delete pv "$POSTGRES_PV" --wait=false
else
  echo "Persistent volume already absent: $POSTGRES_PV"
fi

if [[ "$WAIT_FOR_DELETION" == true ]]; then
  echo "Waiting for namespace deletion (timeout: ${TIMEOUT_SECONDS}s)..."
  for ns in "${NAMESPACES[@]}"; do
    if namespace_exists "$ns"; then
      kubectl wait --for=delete namespace/"$ns" --timeout="${TIMEOUT_SECONDS}s"
      echo "Deleted: $ns"
    else
      echo "Already deleted: $ns"
    fi
  done

  if pv_exists "$POSTGRES_PV"; then
    kubectl wait --for=delete pv/"$POSTGRES_PV" --timeout="${TIMEOUT_SECONDS}s"
    echo "Deleted PV: $POSTGRES_PV"
  else
    echo "PV already deleted: $POSTGRES_PV"
  fi
fi

echo "Cleanup command completed."
