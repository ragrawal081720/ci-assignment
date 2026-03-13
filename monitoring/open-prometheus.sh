#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MONITORING_NAMESPACE:-ci-assignment-monitoring}"
PROMETHEUS_SERVICE="${PROMETHEUS_SERVICE:-prometheus-k8s}"
LOCAL_PORT="${LOCAL_PROMETHEUS_PORT:-9090}"

echo "Prometheus will be available at: http://localhost:${LOCAL_PORT}"
echo "Press Ctrl+C to stop port-forward"
kubectl -n "${MON_NS}" port-forward svc/"${PROMETHEUS_SERVICE}" "${LOCAL_PORT}:9090"
