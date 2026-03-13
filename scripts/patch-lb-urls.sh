#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/patch-lb-urls.sh [namespace] [--force-restart]

Patches app runtime URLs in ConfigMap based on backend/frontend LoadBalancer DNS names,
then restarts only the deployments that need updated values.

Prerequisite:
  kubectl apply -f kube.yaml
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

NAMESPACE="ci-assignment"
FORCE_RESTART="false"

for arg in "$@"; do
  case "$arg" in
    --force-restart)
      FORCE_RESTART="true"
      ;;
    *)
      NAMESPACE="$arg"
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH" >&2
    exit 1
  fi
}

require_cmd kubectl
require_cmd curl

echo "Using namespace: $NAMESPACE"

echo "Fetching LoadBalancer hostname/IP endpoints..."
BACKEND_DNS="$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
FRONTEND_DNS="$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

if [[ -z "$BACKEND_DNS" ]]; then
  BACKEND_DNS="$(kubectl get svc backend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
fi
if [[ -z "$FRONTEND_DNS" ]]; then
  FRONTEND_DNS="$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
fi

if [[ -z "$BACKEND_DNS" || -z "$FRONTEND_DNS" ]]; then
  echo "Error: could not resolve backend/frontend LoadBalancer hostname/IP." >&2
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

CURRENT_FRONTEND_ORIGIN="$(kubectl get configmap app-config -n "$NAMESPACE" -o jsonpath='{.data.FRONTEND_ORIGIN}' 2>/dev/null || true)"
CURRENT_VITE_API_BASE_URL="$(kubectl get configmap app-config -n "$NAMESPACE" -o jsonpath='{.data.VITE_API_BASE_URL}' 2>/dev/null || true)"

BACKEND_NEEDS_RESTART="false"
FRONTEND_NEEDS_RESTART="false"

if [[ "$CURRENT_FRONTEND_ORIGIN" != "$FRONTEND_ORIGIN" ]]; then
  BACKEND_NEEDS_RESTART="true"
fi

if [[ "$CURRENT_VITE_API_BASE_URL" != "$VITE_API_BASE_URL" ]]; then
  FRONTEND_NEEDS_RESTART="true"
fi

if [[ "$FORCE_RESTART" == "true" ]]; then
  BACKEND_NEEDS_RESTART="true"
  FRONTEND_NEEDS_RESTART="true"
fi

if [[ "$BACKEND_NEEDS_RESTART" == "true" || "$FRONTEND_NEEDS_RESTART" == "true" ]]; then
  echo "Patching ConfigMap app-config..."
  kubectl patch configmap app-config -n "$NAMESPACE" --type merge -p \
    "{\"data\":{\"FRONTEND_ORIGIN\":\"$FRONTEND_ORIGIN\",\"VITE_API_BASE_URL\":\"$VITE_API_BASE_URL\"}}"
else
  echo "ConfigMap values already up to date."
fi

if [[ "$BACKEND_NEEDS_RESTART" == "true" ]]; then
  echo "Restarting backend (FRONTEND_ORIGIN changed)..."
  kubectl rollout restart deployment/backend -n "$NAMESPACE"
  kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout=180s
else
  echo "Skipping backend restart (FRONTEND_ORIGIN unchanged)."
fi

if [[ "$FRONTEND_NEEDS_RESTART" == "true" ]]; then
  echo "Restarting frontend (VITE_API_BASE_URL changed)..."
  kubectl rollout restart deployment/frontend -n "$NAMESPACE"
  kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=180s
else
  echo "Skipping frontend restart (VITE_API_BASE_URL unchanged)."
fi

echo "Running quick checks..."
HEALTH_URL="http://$BACKEND_DNS:8000/api/health"
FRONTEND_URL="http://$FRONTEND_DNS:5173"

curl --max-time 12 -fsS "$HEALTH_URL" >/dev/null
curl --max-time 12 -fsS "$FRONTEND_URL" >/dev/null

echo "Success."
echo "Frontend: $FRONTEND_URL"
echo "Backend : http://$BACKEND_DNS:8000/api"
echo "Health  : $HEALTH_URL"
