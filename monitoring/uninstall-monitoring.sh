#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MONITORING_NAMESPACE:-ci-assignment-monitoring}"
KUBE_PROM_VERSION="${KUBE_PROM_VERSION:-v0.14.0}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: required command 'kubectl' is not installed." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: required command 'curl' is not installed." >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "Error: required command 'tar' is not installed." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

ARCHIVE="${TMP_DIR}/kube-prometheus.tar.gz"
DOWNLOAD_URL="https://codeload.github.com/prometheus-operator/kube-prometheus/tar.gz/refs/tags/${KUBE_PROM_VERSION}"

echo "Downloading kube-prometheus ${KUBE_PROM_VERSION} manifests..."
curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE}"
tar -xzf "${ARCHIVE}" -C "${TMP_DIR}"

KP_DIR="${TMP_DIR}/kube-prometheus-${KUBE_PROM_VERSION#v}"
if [[ ! -d "${KP_DIR}/manifests" ]]; then
  echo "Error: unexpected archive layout for ${KUBE_PROM_VERSION}." >&2
  exit 1
fi

RENDER_DIR="${TMP_DIR}/rendered"
cp -R "${KP_DIR}/manifests" "${RENDER_DIR}"

# Keep uninstall namespace-aligned with install rendering.
while IFS= read -r -d '' f; do
  sed -i '' \
    -e "s/namespace: monitoring/namespace: ${MON_NS}/g" \
    -e "s/name: monitoring$/name: ${MON_NS}/g" \
    "$f"
done < <(find "${RENDER_DIR}" -type f -name '*.yaml' -print0)

echo "Deleting custom monitoring resources in namespace '${MON_NS}' if present..."
kubectl delete prometheusrule app-infra-alerts -n "${MON_NS}" --ignore-not-found
kubectl delete servicemonitor backend -n "${MON_NS}" --ignore-not-found
kubectl delete rolebinding prometheus-k8s -n "${APP_NAMESPACE:-ci-assignment}" --ignore-not-found
kubectl delete role prometheus-k8s -n "${APP_NAMESPACE:-ci-assignment}" --ignore-not-found

echo "Deleting kube-prometheus workloads..."
kubectl delete -f "${RENDER_DIR}" --ignore-not-found=true

echo "Deleting kube-prometheus setup resources..."
kubectl delete -f "${RENDER_DIR}/setup" --ignore-not-found=true

echo "Uninstall complete."
