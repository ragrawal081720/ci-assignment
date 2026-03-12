#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/patch-lb-urls.sh [namespace]

Patches app runtime URLs in ConfigMap based on backend/frontend LoadBalancer DNS names,
then restarts backend followed by frontend.

Prerequisite:
  kubectl apply -f kube.yaml
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

NAMESPACE="${1:-ci-assignment}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH" >&2
    exit 1
  fi
}

require_cmd kubectl
require_cmd curl

echo "Using namespace: $NAMESPACE"

echo "Fetching LoadBalancer hostnames..."
BACKEND_DNS="$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
FRONTEND_DNS="$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

if [[ -z "$BACKEND_DNS" || -z "$FRONTEND_DNS" ]]; then
  echo "Error: could not resolve backend/frontend LoadBalancer DNS names." >&2
  echo "Make sure services exist and EXTERNAL-IP is assigned:" >&2
  echo "  kubectl get svc -n $NAMESPACE" >&2
  exit 1
fi

FRONTEND_ORIGIN="http://$FRONTEND_DNS:5173"
VITE_API_BASE_URL="http://$BACKEND_DNS:8000/api"

echo "Backend DNS : $BACKEND_DNS"
echo "Frontend DNS: $FRONTEND_DNS"
echo "FRONTEND_ORIGIN=$FRONTEND_ORIGIN"
echo "VITE_API_BASE_URL=$VITE_API_BASE_URL"

echo "Patching ConfigMap app-config..."
kubectl patch configmap app-config -n "$NAMESPACE" --type merge -p \
  "{\"data\":{\"FRONTEND_ORIGIN\":\"$FRONTEND_ORIGIN\",\"VITE_API_BASE_URL\":\"$VITE_API_BASE_URL\"}}"

echo "Restarting backend (first)..."
kubectl rollout restart deployment/backend -n "$NAMESPACE"
kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout=180s

echo "Restarting frontend (second)..."
kubectl rollout restart deployment/frontend -n "$NAMESPACE"
kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=180s

echo "Running quick checks..."
HEALTH_URL="http://$BACKEND_DNS:8000/api/health"
FRONTEND_URL="http://$FRONTEND_DNS:5173"

curl --max-time 12 -fsS "$HEALTH_URL" >/dev/null
curl --max-time 12 -fsS "$FRONTEND_URL" >/dev/null

echo "Success."
echo "Frontend: $FRONTEND_URL"
echo "Backend : http://$BACKEND_DNS:8000/api"
echo "Health  : $HEALTH_URL"
