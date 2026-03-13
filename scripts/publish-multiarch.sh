#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dockerhub-username> [commit-sha]"
  echo "Example: $0 ragrawal081720"
  echo "Example: $0 ragrawal081720 \\$(git rev-parse --short HEAD)"
  exit 1
fi

DOCKERHUB_USER="$1"
COMMIT_SHA="${2:-$(git rev-parse --short HEAD)}"
COMMIT_SHA="${COMMIT_SHA#sha-}"
SHA_TAG="sha-${COMMIT_SHA}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDER_NAME="ci-assignment-builder"

# Reuse an existing buildx builder when available.
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER_NAME" --use >/dev/null
else
  docker buildx use "$BUILDER_NAME"
fi

echo "Publishing multi-arch backend image..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "$DOCKERHUB_USER/books-backend:$SHA_TAG" \
  -t "$DOCKERHUB_USER/books-backend:latest" \
  -f "$ROOT_DIR/backend/Dockerfile" \
  "$ROOT_DIR/backend" \
  --push

echo "Publishing multi-arch frontend image..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "$DOCKERHUB_USER/books-frontend:$SHA_TAG" \
  -t "$DOCKERHUB_USER/books-frontend:latest" \
  -f "$ROOT_DIR/frontend/Dockerfile" \
  "$ROOT_DIR/frontend" \
  --push

echo "Done. Published tags:"
echo "  $DOCKERHUB_USER/books-backend:$SHA_TAG"
echo "  $DOCKERHUB_USER/books-backend:latest"
echo "  $DOCKERHUB_USER/books-frontend:$SHA_TAG"
echo "  $DOCKERHUB_USER/books-frontend:latest"
