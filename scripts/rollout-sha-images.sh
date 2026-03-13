#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dockerhub-username> [namespace] [commit-sha]"
  echo "Example: $0 ragrawal081720"
  echo "Example: $0 ragrawal081720 ci-assignment ab12cd3"
  exit 1
fi

DOCKERHUB_USER="$1"
NAMESPACE="${2:-ci-assignment}"
COMMIT_SHA="${3:-$(git rev-parse --short HEAD)}"
COMMIT_SHA="${COMMIT_SHA#sha-}"
SHA_TAG="sha-${COMMIT_SHA}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH" >&2
    exit 1
  fi
}

require_cmd kubectl

if ! kubectl kustomize --help >/dev/null 2>&1; then
  echo "Error: this kubectl build does not include kustomize support." >&2
  echo "Use a newer kubectl version that supports 'kubectl apply -k'." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cp "$ROOT_DIR/kube.yaml" "$TMP_DIR/kube.yaml"

cat > "$TMP_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - kube.yaml
images:
  - name: ragrawal081720/books-backend
    newName: ${DOCKERHUB_USER}/books-backend
    newTag: ${SHA_TAG}
  - name: ragrawal081720/books-frontend
    newName: ${DOCKERHUB_USER}/books-frontend
    newTag: ${SHA_TAG}
EOF

echo "Applying manifests declaratively via kustomize overlay..."
kubectl apply -k "$TMP_DIR"

kubectl rollout status deployment/backend -n "$NAMESPACE"

kubectl rollout status deployment/frontend -n "$NAMESPACE"

echo "Rolled out declarative deployment with tag $SHA_TAG in namespace $NAMESPACE"
