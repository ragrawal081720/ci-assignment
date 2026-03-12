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
export BACKEND_IMAGE=<your-dockerhub-username>/books-backend:latest
export FRONTEND_IMAGE=<your-dockerhub-username>/books-frontend:latest
docker compose build
docker compose push
```

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

Use the single manifest in repo root:

```bash
kubectl apply -f kube.yaml
```

After external DNS names are assigned to services, patch runtime URLs:

```bash
./scripts/patch-lb-urls.sh
```

Optional namespace override:

```bash
./scripts/patch-lb-urls.sh <namespace>
```
