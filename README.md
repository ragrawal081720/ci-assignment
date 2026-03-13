# CI Assignment: Books CRUD Platform

Full-stack Books CRUD application with:
- FastAPI backend (`/api`), PostgreSQL persistence, and Redis-backed list caching
- React + Vite frontend
- Local orchestration with Docker Compose
- Kubernetes deployment via raw manifests (`kube.yaml`) or Helm chart
- Monitoring stack (Prometheus + Grafana) installed via scripts
- GitHub Actions for CI, CD, Terraform provisioning, and manual operations

## Architecture

Runtime components:
- Frontend (`frontend`) calls backend using `VITE_API_BASE_URL`
- Backend (`backend`) exposes:
	- CRUD endpoints under `/api/books`
	- health endpoint at `/api/health`
	- Prometheus metrics at `/metrics`
- PostgreSQL stores book records
- Redis caches the result of `GET /api/books` with TTL from `CACHE_TTL_SECONDS`

Deployment options:
- Local: Docker Compose (`docker-compose.yml`)
- Kubernetes manifests: `kube.yaml` + helper scripts in `scripts/`
- Helm chart: `helm/ci-assignment`

## Repository Layout

Key paths:
- `backend/` FastAPI app, Alembic migrations, Dockerfile
- `frontend/` React app, Vite config, Dockerfile
- `kube.yaml` Kubernetes namespace + app resources (Postgres, Redis, backend, frontend)
- `helm/ci-assignment/` Helm chart for app deployment
- `monitoring/` kube-prometheus install/uninstall/open scripts + alerting/ServiceMonitor manifests
- `scripts/` deployment, URL patching, image publish, and cleanup helpers
- `terraform/eks/` EKS and VPC provisioning stack
- `terraform/ecr/` ECR provisioning stack
- `.github/workflows/` CI/CD/manual workflow definitions

## Prerequisites

- Docker (with Buildx if publishing multi-arch images)
- `kubectl` configured for target cluster
- `helm` (only for Helm deployment path)
- Docker Hub credentials (for image push)
- For monitoring install script: `curl`, `tar`, `sed`
- For Terraform path: Terraform + AWS credentials

## 1. Run Locally (Docker Compose)

From repo root:

```bash
cp .env.example .env
docker compose up --build
```

Local URLs:
- Frontend: `http://localhost:5173`
- Backend API base: `http://localhost:8000/api`
- Health: `http://localhost:8000/api/health`
- Metrics: `http://localhost:8000/metrics`

Stop services:

```bash
docker compose down
```

Stop and remove Postgres volume:

```bash
docker compose down -v
```

## 2. Configuration

Main runtime env vars (from `.env.example` and app config):
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_DB`, `CACHE_TTL_SECONDS`
- `FRONTEND_ORIGIN` (CORS allowlist value for backend)
- `VITE_API_BASE_URL` (frontend backend URL)
- `BACKEND_IMAGE`, `FRONTEND_IMAGE` (used by Docker Compose)

Defaults are tuned for local development (`localhost` endpoints).

## 3. Build and Push Multi-Arch Images

Use helper script:

```bash
docker login
./scripts/publish-multiarch.sh <dockerhub-username>
```

Optional explicit SHA/tag seed:

```bash
./scripts/publish-multiarch.sh <dockerhub-username> <commit-sha>
```

Published tags:
- `<dockerhub-username>/books-backend:sha-<short-sha>`
- `<dockerhub-username>/books-backend:latest`
- `<dockerhub-username>/books-frontend:sha-<short-sha>`
- `<dockerhub-username>/books-frontend:latest`

## 4. Deploy to Kubernetes (Manifests)

### 4.1 First-time/base apply

```bash
kubectl apply -f kube.yaml
```

`kube.yaml` creates:
- Namespace `ci-assignment`
- Secret `app-secrets` and ConfigMap `app-config`
- Postgres + Redis deployments/services
- Backend + frontend deployments/services (both `LoadBalancer`)
- Static hostPath-based PV/PVC (`postgres-pv-local` / `postgres-pvc`)

### 4.2 Roll out SHA images (recommended for updates)

`scripts/rollout-sha-images.sh` applies `kube.yaml` through a generated kustomize overlay with image replacements.

```bash
./scripts/rollout-sha-images.sh <dockerhub-username>
```

Variants:
- `./scripts/rollout-sha-images.sh <dockerhub-username> <namespace>`
- `./scripts/rollout-sha-images.sh <dockerhub-username> <namespace> <commit-sha>`

### 4.3 Patch LB URLs into runtime config

After services receive external DNS/IP, patch and restart safely:

```bash
./scripts/patch-lb-urls.sh
```

Optional:
- Namespace override: `./scripts/patch-lb-urls.sh <namespace>`
- Force restart: `./scripts/patch-lb-urls.sh <namespace> --force-restart`

What it does:
- Reads backend/frontend `LoadBalancer` hostname/IP
- Updates `app-config` with:
	- `FRONTEND_ORIGIN=http://<frontend-endpoint>:5173`
	- `VITE_API_BASE_URL=http://<backend-endpoint>:8000/api`
- Restarts backend/frontend only when values changed
- Runs quick curl checks against health/frontend URLs

### 4.4 Verify

```bash
kubectl get pods -n ci-assignment
kubectl get svc -n ci-assignment
```

Then test:

```bash
curl -i "http://<backend-endpoint>:8000/api/health"
curl -i "http://<frontend-endpoint>:5173"
```

## 5. Deploy with Helm (Optional)

Chart path: `helm/ci-assignment`

Validate:

```bash
helm lint helm/ci-assignment
helm template ci-assignment helm/ci-assignment
```

Install/upgrade:

```bash
kubectl create namespace ci-assignment --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install ci-assignment helm/ci-assignment -n ci-assignment
```

Override images:

```bash
helm upgrade --install ci-assignment helm/ci-assignment \
	-n ci-assignment \
	--set backend.image.repository=<dockerhub-user>/books-backend \
	--set backend.image.tag=sha-<short-sha> \
	--set frontend.image.repository=<dockerhub-user>/books-frontend \
	--set frontend.image.tag=sha-<short-sha>
```

LoadBalancer URL patch hook behavior:
- Enabled by default (`lbUrlPatching.enabled=true`)
- Waits for LB endpoints and patches `app-config` values
- Restarts only when values change

Disable hook patching:

```bash
helm upgrade --install ci-assignment helm/ci-assignment \
	-n ci-assignment \
	--set lbUrlPatching.enabled=false
```

Uninstall:

```bash
helm uninstall ci-assignment -n ci-assignment
```

## 6. Monitoring (Prometheus + Grafana)

Install kube-prometheus stack using scripts:

```bash
./monitoring/install-monitoring.sh
```

Useful overrides:

```bash
MONITORING_NAMESPACE=ci-assignment-monitoring APP_NAMESPACE=ci-assignment KUBE_PROM_VERSION=v0.14.0 ./monitoring/install-monitoring.sh
MINIMAL_PROFILE=false ./monitoring/install-monitoring.sh
```

Open UIs:

```bash
./monitoring/open-grafana.sh
./monitoring/open-prometheus.sh
```

Default local URLs:
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`

Grafana credentials:
- Username: `admin`
- Password (read from cluster secret):

```bash
if kubectl get secret grafana-admin-credentials -n ci-assignment-monitoring >/dev/null 2>&1; then
	kubectl get secret grafana-admin-credentials -n ci-assignment-monitoring -o jsonpath='{.data.admin-password}' | base64 --decode && echo
else
	kubectl get secret grafana -n ci-assignment-monitoring -o jsonpath='{.data.admin-password}' | base64 --decode && echo
fi
```

Uninstall:

```bash
./monitoring/uninstall-monitoring.sh
```

## 7. Cleanup Helpers

Delete app and monitoring namespaces:

```bash
./scripts/cleanup-namespaces.sh
```

Delete and wait:

```bash
./scripts/cleanup-namespaces.sh --wait --timeout 300
```

Verify namespace cleanup:

```bash
./scripts/verify-namespaces-cleanup.sh
```

## 8. API Reference

Books:
- `POST /api/books`
- `GET /api/books`
- `GET /api/books/{book_id}`
- `PUT /api/books/{book_id}`
- `DELETE /api/books/{book_id}`

Operational:
- `GET /api/health` (returns `ok` or `degraded` based on DB/Redis checks)
- `GET /metrics` (Prometheus scrape endpoint)

## 9. GitHub Actions Workflows

Workflows in `.github/workflows/`:

- `ci-build-push.yml`
	- Trigger: push to `main` (selected paths) and tags `v*`
	- Purpose: build and push multi-arch images to Docker Hub

- `ci-cd-build-push-deploy.yml`
	- Trigger: manual (`workflow_dispatch`)
	- Purpose: publish images and deploy to Kubernetes (`ci-assignment` namespace)

- `cd-manual-deploy.yml`
	- Trigger: manual (`workflow_dispatch`)
	- Purpose: deploy a SHA image to chosen namespace using existing published images

- `helm-manual-deploy.yml`
	- Trigger: manual (`workflow_dispatch`)
	- Purpose: deploy app via Helm chart

- `monitoring-manual.yml`
	- Trigger: manual (`workflow_dispatch`)
	- Purpose: install/uninstall monitoring stack

- `terraform-provision.yml`
	- Trigger: manual (`workflow_dispatch`)
	- Purpose: Terraform plan/apply, then (for `apply`) publish + deploy

Common required secrets for deploy/infra workflows:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `KUBECONFIG_B64` (for kubeconfig-based deploy workflows)
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Generate `KUBECONFIG_B64` locally:

```bash
base64 < ~/.kube/config | tr -d '\n'
```

## 10. Terraform Infra (EKS)

`terraform/eks/main.tf` provisions:
- VPC with public subnets
- EKS cluster (`cluster_name` default: `ci-eks-cluster`)
- Managed node group (default `t3.small`, desired size `2`)

Quick run:

```bash
cd terraform/eks
terraform init
terraform plan
terraform apply
```

Useful overrides:

```bash
terraform apply \
	-var="aws_region=ap-south-1" \
	-var="cluster_name=ci-eks-cluster" \
	-var="vpc_cidr=10.0.0.0/16"
```

After apply, configure kubeconfig:

```bash
aws eks update-kubeconfig --name ci-eks-cluster --region ap-south-1
```

## 10.1 Terraform ECR (separate state)

`terraform/ecr/` provisions only ECR resources in a separate Terraform stack:
- ECR repository
- ECR lifecycle policy

Quick run:

```bash
cd terraform/ecr
terraform init
terraform plan
terraform apply
```

## 11. Deployment Workflow Challenges and Lessons Learned

### Cluster targeting across separate workflows

Challenge:
- `terraform-provision.yml` can create/update EKS and exposes `cluster_name` only inside that workflow run.
- Separate deploy workflows (`cd-manual-deploy.yml`, `ci-cd-build-push-deploy.yml`, `helm-manual-deploy.yml`) do not consume Terraform outputs.

Current behavior:
- Deploy workflows target whichever cluster is referenced by `KUBECONFIG_B64`.
- Running Terraform first does not automatically retarget later deploy workflows.

Impact:
- Deploy can fail or deploy to the wrong cluster if `KUBECONFIG_B64` is stale or points to a different context.

Recommended practice:
- Treat `KUBECONFIG_B64` as the source of truth for standalone deploy workflows, and rotate/update it whenever cluster context changes.
- Prefer environment-specific variables/secrets (for example, `EKS_CLUSTER_NAME` + `AWS_REGION`) and generate kubeconfig in workflow via `aws eks update-kubeconfig`.

### Existing cluster vs Terraform state

Challenge:
- If an EKS cluster with the same name already exists but is not tracked in Terraform state, `terraform apply` attempts to create it again.

Impact:
- Apply fails with resource-exists/name-conflict errors.

Recommended practice:
- Use remote state and keep state authoritative.
- Import pre-existing resources before managing them with Terraform, or use a different cluster name.

### Helm namespace creation flag confusion

Challenge:
- In `helm-manual-deploy.yml`, `create_namespace` controls chart-level namespace manifest rendering (`namespace.create`), not Helm CLI `--create-namespace`.

Current behavior:
- `create_namespace=true`: chart renders a `Namespace` resource.
- `create_namespace=false`: workflow ensures namespace with `kubectl apply` before Helm deploy.

Recommended practice:
- Keep `create_namespace=false` as a safer default when namespace ownership is external or may already exist.
- Use `true` only when Helm should own namespace creation and RBAC allows namespace creation.

## 12. Troubleshooting

### `kubectl` cannot find namespace `ci-assignment`

Symptoms:
- `kubectl get ns ci-assignment` returns NotFound

Fix:

```bash
kubectl apply -f kube.yaml
kubectl get ns ci-assignment
```

### Backend/frontend `LoadBalancer` endpoint stays pending

Symptoms:
- `kubectl get svc -n ci-assignment` shows `<pending>` for `EXTERNAL-IP`

Checks:

```bash
kubectl get svc -n ci-assignment
kubectl describe svc backend -n ci-assignment
kubectl describe svc frontend -n ci-assignment
```

Notes:
- This usually indicates cloud LB provisioning is still in progress or cluster/network permissions are incomplete.
- Patch URLs only after both backend and frontend have an external hostname/IP.

### CORS errors from frontend to backend

Symptoms:
- Browser shows CORS blocked request for backend API calls

Fix:

```bash
./scripts/patch-lb-urls.sh ci-assignment
kubectl get configmap app-config -n ci-assignment -o yaml | grep -E 'FRONTEND_ORIGIN|VITE_API_BASE_URL'
```

`FRONTEND_ORIGIN` must match the frontend URL (including `http://` and `:5173`).

### Pods in `CrashLoopBackOff` or not Ready

Checks:

```bash
kubectl get pods -n ci-assignment
kubectl describe pod <pod-name> -n ci-assignment
kubectl logs <pod-name> -n ci-assignment --previous
```

If backend is failing, verify DB/Redis readiness:

```bash
kubectl get pods -n ci-assignment -l app=postgres
kubectl get pods -n ci-assignment -l app=redis
```

### Monitoring UI not reachable locally

Checks:

```bash
kubectl get pods -n ci-assignment-monitoring
kubectl get svc -n ci-assignment-monitoring
```

Re-open port-forwards:

```bash
./monitoring/open-grafana.sh
./monitoring/open-prometheus.sh
```

### Fresh redeploy keeps old state

Use cleanup helpers and redeploy:

```bash
./scripts/cleanup-namespaces.sh --wait --timeout 300
kubectl apply -f kube.yaml
```
