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

kubectl set image deployment/backend backend="$DOCKERHUB_USER/books-backend:$SHA_TAG" -n "$NAMESPACE"
kubectl rollout status deployment/backend -n "$NAMESPACE"

kubectl set image deployment/frontend frontend="$DOCKERHUB_USER/books-frontend:$SHA_TAG" -n "$NAMESPACE"
kubectl rollout status deployment/frontend -n "$NAMESPACE"

echo "Rolled out images tagged with $SHA_TAG in namespace $NAMESPACE"
