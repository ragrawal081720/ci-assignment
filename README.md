# Books CRUD App (Backend + Frontend)

This repository contains a Books CRUD implementation with:
- FastAPI backend
- PostgreSQL persistence via SQLAlchemy
- Redis list caching
- React + Vite frontend

Containerization is included with custom Dockerfiles for backend and frontend, plus docker-compose for orchestration.

## 1. Run with Docker Compose (recommended)

From repository root:

```bash
cp .env.example .env
docker compose build
docker compose up
```

Application URLs:
- Frontend: `http://localhost:5173`
- Backend API: `http://localhost:8000/api`
- Health: `http://localhost:8000/api/health`

Stop services:

```bash
docker compose down
```

Stop and remove database volume:

```bash
docker compose down -v
```

Push backend and frontend images to Docker Hub:

```bash
docker login
./scripts/publish-multiarch.sh <your-dockerhub-username>
```

Example:

```bash
./scripts/publish-multiarch.sh ragrawal081720
```

This publishes both `linux/amd64` and `linux/arm64` images and tags each image with both `sha-<current-commit>` and `latest`.

## 2. Backend setup (without Docker)

From `backend/`:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Copy env template at repo root and adjust values as needed:

```bash
cp ../.env.example ../.env
```

Run Alembic migration (from `backend/`):

```bash
alembic upgrade head
```

Start API server:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API base URL: `http://localhost:8000/api`

## 3. Frontend setup (without Docker)

From `frontend/`:

```bash
npm install
npm run dev
```

Frontend URL: `http://localhost:5173`

The frontend reads API URL from `VITE_API_BASE_URL` and defaults to `http://localhost:8000/api`.

## 4. Implemented endpoints

- `POST /api/books`
- `GET /api/books`
- `GET /api/books/{book_id}`
- `PUT /api/books/{book_id}`
- `DELETE /api/books/{book_id}`
- `GET /api/health`

## 5. Book schema

- `id` (int)
- `title` (string)
- `author` (string)
- `genre` (string)
- `created_at` (datetime)
- `updated_at` (datetime)

## 6. Redis behavior

- `GET /api/books` caches list responses.
- Cache is invalidated on create, update, and delete.

## 7. Kubernetes deployment (dual LoadBalancer)

`kube.yaml` uses `latest` for first-time bootstrap. For deterministic rollouts, apply a declarative Kustomize overlay with exact commit image tags:

```bash
./scripts/rollout-sha-images.sh <your-dockerhub-username>
```

Use the single manifest in repo root:

```bash
kubectl apply -f kube.yaml
```

After external DNS names are assigned to services, patch runtime URLs and restart deployments in the safe order (backend, then frontend):

```bash
./scripts/patch-lb-urls.sh
```

Optional namespace override:

```bash
./scripts/patch-lb-urls.sh <namespace>
```

Useful rollout/cleanup helpers:

```bash
# Deploy backend/frontend declaratively with sha-<commit> tags
./scripts/rollout-sha-images.sh <your-dockerhub-username>

# Delete app + monitoring namespaces (non-blocking)
./scripts/cleanup-namespaces.sh

# Delete and wait for completion
./scripts/cleanup-namespaces.sh --wait --timeout 300

# Verify both namespaces are gone (exit 0 on success)
./scripts/verify-namespaces-cleanup.sh
```

## 8. Monitoring stack

Monitoring assets live in `monitoring/` and install Prometheus + Grafana via `kubectl` manifests (no Helm required).

```bash
./monitoring/install-monitoring.sh
./monitoring/open-grafana.sh
./monitoring/open-prometheus.sh
```

Optional environment overrides are supported:

```bash
MONITORING_NAMESPACE=ci-assignment-monitoring APP_NAMESPACE=ci-assignment ./monitoring/install-monitoring.sh
```

For monitoring details and alert/ServiceMonitor notes, see `monitoring/README.md`.

## 9. GitHub Actions CI/CD

Workflow file: `.github/workflows/ci-cd-build-push-deploy.yml`

On push to `main` (backend/frontend/kube/scripts/workflow changes), the pipeline:
- Builds and pushes multi-arch backend/frontend images to Docker Hub
- Tags images with both `latest` and `sha-<commit>`
- Applies `kube.yaml` to the cluster
- Deploys SHA-pinned images via `./scripts/rollout-sha-images.sh`
- Waits for LoadBalancer hostnames and patches runtime URLs via `./scripts/patch-lb-urls.sh`

Required GitHub repository secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `KUBECONFIG_B64` (base64-encoded kubeconfig content)

Optional GitHub repository variable:
- `K8S_NAMESPACE` (defaults to `ci-assignment`)

Create `KUBECONFIG_B64` value locally with:

```bash
base64 < ~/.kube/config | tr -d '\n'
```
