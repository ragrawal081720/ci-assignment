# EKS Monitoring Scripts

This folder contains scripts/manifests to install Prometheus + Grafana in your EKS cluster and monitor both cluster infrastructure and app workloads.

## Files

- `install-monitoring.sh`: Installs/updates Prometheus Operator stack (`kube-prometheus`) using pure `kubectl` (no Helm) and applies app/infrastructure monitoring resources.
- `backend-servicemonitor.yaml`: Scrapes backend metrics endpoint (`/metrics`) from `ci-assignment` namespace.
- `app-namespace-rbac.yaml`: Grants Prometheus service account read access to app namespace services/pods/endpoints.
- `app-infra-alerts.yaml`: Example infra/app alerts (node CPU/memory, pod restarts, replica mismatch).
- `open-grafana.sh`: Port-forward Grafana to `http://localhost:3000`.
- `open-prometheus.sh`: Port-forward Prometheus to `http://localhost:9090`.
- `uninstall-monitoring.sh`: Removes monitoring stack resources.

## Prerequisites

- `kubectl` configured for your EKS cluster
- `curl` and `tar` installed (used to fetch upstream manifests)
- App namespace deployed (default: `ci-assignment`)

Default install mode is a minimal profile for small clusters:
- `Alertmanager` replicas reduced to 1
- `Prometheus` replicas reduced to 1 with lower memory/CPU requests
- `prometheus-adapter` scaled to 0
- `blackbox-exporter` scaled to 0

## Install

From repo root:

```bash
./monitoring/install-monitoring.sh
```

Optional overrides:

```bash
MONITORING_NAMESPACE=ci-assignment-monitoring APP_NAMESPACE=ci-assignment KUBE_PROM_VERSION=v0.14.0 ./monitoring/install-monitoring.sh
```

Install full profile (non-minimal defaults):

```bash
MINIMAL_PROFILE=false ./monitoring/install-monitoring.sh
```

## Access dashboards

```bash
./monitoring/open-grafana.sh
./monitoring/open-prometheus.sh
```

Grafana username is `admin`.
Password is printed by `install-monitoring.sh` and can be fetched again with:

```bash
kubectl get secret grafana-admin-credentials -n ci-assignment-monitoring -o jsonpath='{.data.admin-password}' | base64 --decode && echo
```

## Important note for backend app metrics

Your backend service must expose a Prometheus endpoint at `/metrics` on port `8000` (service port name `http`).
If `/metrics` is not implemented yet, infrastructure metrics and alerts still work, but the backend ServiceMonitor target will show as down.

The installer also applies app-namespace RBAC so Prometheus can discover targets in `APP_NAMESPACE`.

## Uninstall

```bash
./monitoring/uninstall-monitoring.sh
```
