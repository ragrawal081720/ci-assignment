#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MONITORING_NAMESPACE:-ci-assignment-monitoring}"
GRAFANA_SERVICE="${GRAFANA_SERVICE:-grafana}"
LOCAL_PORT="${LOCAL_GRAFANA_PORT:-3000}"

echo "Grafana will be available at: http://localhost:${LOCAL_PORT}"
echo "Press Ctrl+C to stop port-forward"
kubectl -n "${MON_NS}" port-forward svc/"${GRAFANA_SERVICE}" "${LOCAL_PORT}:3000"
