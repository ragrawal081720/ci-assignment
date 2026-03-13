#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/verify-namespaces-cleanup.sh

Verifies project namespaces are fully cleaned up:
  - ci-assignment
  - ci-assignment-monitoring

Exit codes:
  0 = all namespaces absent
  1 = one or more namespaces still exist
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH" >&2
    exit 1
  fi
}

require_cmd kubectl

NAMESPACES=("ci-assignment" "ci-assignment-monitoring")
ALL_CLEAN=true

for ns in "${NAMESPACES[@]}"; do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "$ns: present"
    ALL_CLEAN=false
  else
    echo "$ns: absent"
  fi
done

if [[ "$ALL_CLEAN" == true ]]; then
  echo "Result: cleanup verified."
  exit 0
fi

echo "Result: cleanup incomplete."
exit 1
