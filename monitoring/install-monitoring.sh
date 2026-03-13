#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MON_NS="${MONITORING_NAMESPACE:-ci-assignment-monitoring}"
APP_NS="${APP_NAMESPACE:-ci-assignment}"
KUBE_PROM_VERSION="${KUBE_PROM_VERSION:-v0.14.0}"
MINIMAL_PROFILE="${MINIMAL_PROFILE:-true}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' is not installed." >&2
    exit 1
  fi
}

require_cmd kubectl
require_cmd curl
require_cmd tar
require_cmd sed

sed_in_place() {
  local file="$1"
  shift

  # BSD sed (macOS) requires a backup suffix argument for -i.
  if sed --version >/dev/null 2>&1; then
    sed -i "$@" "$file"
  else
    sed -i '' "$@" "$file"
  fi
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

ARCHIVE="${TMP_DIR}/kube-prometheus.tar.gz"
DOWNLOAD_URL="https://codeload.github.com/prometheus-operator/kube-prometheus/tar.gz/refs/tags/${KUBE_PROM_VERSION}"

echo "[1/6] Downloading kube-prometheus ${KUBE_PROM_VERSION}..."
curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE}"
tar -xzf "${ARCHIVE}" -C "${TMP_DIR}"

KP_DIR="${TMP_DIR}/kube-prometheus-${KUBE_PROM_VERSION#v}"
if [[ ! -d "${KP_DIR}/manifests" ]]; then
  echo "Error: unexpected archive layout for ${KUBE_PROM_VERSION}." >&2
  exit 1
fi

RENDER_DIR="${TMP_DIR}/rendered"
cp -R "${KP_DIR}/manifests" "${RENDER_DIR}"

# kube-prometheus manifests are namespace-hardcoded to 'monitoring'.
# Rewrite them so the stack can be installed to a custom namespace.
while IFS= read -r -d '' f; do
  sed_in_place "$f" \
    -e "s/namespace: monitoring/namespace: ${MON_NS}/g" \
    -e "s/name: monitoring$/name: ${MON_NS}/g" \
    -e "s/\.monitoring\.svc\.cluster\.local/.${MON_NS}.svc.cluster.local/g" \
    -e "s/\.monitoring\.svc/.${MON_NS}.svc/g"
done < <(find "${RENDER_DIR}" -type f -name '*.yaml' -print0)

apply_minimal_profile() {
  echo "Applying minimal resource profile..."

  # Keep Alertmanager footprint low for small clusters.
  kubectl patch alertmanager main -n "${MON_NS}" --type merge \
    -p '{"spec":{"replicas":1}}' >/dev/null 2>&1 || true

  # Run a single Prometheus replica with smaller resource requests.
  kubectl patch prometheus k8s -n "${MON_NS}" --type merge \
    -p '{"spec":{"replicas":1,"retention":"24h","resources":{"requests":{"cpu":"100m","memory":"300Mi"},"limits":{"cpu":"500m","memory":"700Mi"}}}}' >/dev/null 2>&1 || true

  # Disable optional components that consume extra pod slots.
  kubectl scale deployment prometheus-adapter -n "${MON_NS}" --replicas=0 >/dev/null 2>&1 || true
  kubectl scale deployment blackbox-exporter -n "${MON_NS}" --replicas=0 >/dev/null 2>&1 || true
}

echo "[2/6] Applying kube-prometheus CRDs and setup objects..."
kubectl apply --server-side -f "${RENDER_DIR}/setup"

echo "[3/6] Waiting for monitoring CRDs to be established..."
for crd in \
  alertmanagers.monitoring.coreos.com \
  podmonitors.monitoring.coreos.com \
  probes.monitoring.coreos.com \
  prometheuses.monitoring.coreos.com \
  prometheusrules.monitoring.coreos.com \
  servicemonitors.monitoring.coreos.com; do
  until kubectl get crd "${crd}" >/dev/null 2>&1; do
    sleep 2
  done
done

echo "[4/6] Applying kube-prometheus workloads..."
kubectl apply -f "${RENDER_DIR}"

if [[ "${MINIMAL_PROFILE}" == "true" ]]; then
  apply_minimal_profile
fi

echo "[5/6] Waiting for operator and Grafana deployments..."
kubectl rollout status deployment/prometheus-operator -n "${MON_NS}" --timeout=10m
kubectl rollout status deployment/grafana -n "${MON_NS}" --timeout=10m

echo "[6/6] Applying app and infra monitoring manifests..."
for f in app-namespace-rbac.yaml app-infra-alerts.yaml backend-servicemonitor.yaml; do
  sed \
    -e "s/__APP_NAMESPACE__/${APP_NS}/g" \
    -e "s/__MONITORING_NAMESPACE__/${MON_NS}/g" \
    "${SCRIPT_DIR}/${f}" | kubectl apply -f -
done

echo "Monitoring stack is ready."
echo
echo "Grafana admin password:"
if kubectl get secret grafana-admin-credentials -n "${MON_NS}" >/dev/null 2>&1; then
  kubectl get secret grafana-admin-credentials -n "${MON_NS}" -o jsonpath='{.data.admin-password}' | base64 --decode
elif kubectl get secret grafana -n "${MON_NS}" >/dev/null 2>&1; then
  kubectl get secret grafana -n "${MON_NS}" -o jsonpath='{.data.admin-password}' | base64 --decode
else
  echo "(not found automatically; check secrets in namespace '${MON_NS}')"
fi
echo
echo
echo "Access commands:"
echo "  ${SCRIPT_DIR}/open-grafana.sh"
echo "  ${SCRIPT_DIR}/open-prometheus.sh"
if [[ "${MINIMAL_PROFILE}" == "true" ]]; then
  echo
  echo "Minimal profile is enabled (MINIMAL_PROFILE=true)."
  echo "Set MINIMAL_PROFILE=false to install full kube-prometheus defaults."
fi
