# Dual LoadBalancer Runbook (ci-assignment)

Use this when deploying `kube.yaml` on EKS.

## 0. Image preflight

Each commit should publish `sha-<commit>` plus `latest`. Use `sha-<commit>` for deterministic deployment and keep `latest` as the moving pointer to current main.

```bash
docker login
./scripts/publish-multiarch.sh <your-dockerhub-username>

# Optional: verify both amd64 and arm64 are present
SHA_TAG="sha-$(git rev-parse --short HEAD)"
docker manifest inspect <your-dockerhub-username>/books-frontend:$SHA_TAG | jq -r '.manifests[]?.platform | "\(.os)/\(.architecture)"'
docker manifest inspect <your-dockerhub-username>/books-backend:$SHA_TAG | jq -r '.manifests[]?.platform | "\(.os)/\(.architecture)"'
```

## 1. Deploy

```bash
kubectl apply -f kube.yaml
```

## 2. Wait for ELB hostnames

```bash
kubectl get svc -n ci-assignment -w
```

Wait until `backend` and `frontend` show non-`<pending>` values in `EXTERNAL-IP`.

## 3. Capture DNS names

```bash
BACKEND_DNS=$(kubectl get svc backend -n ci-assignment -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
FRONTEND_DNS=$(kubectl get svc frontend -n ci-assignment -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "BACKEND_DNS=$BACKEND_DNS"
echo "FRONTEND_DNS=$FRONTEND_DNS"
```

## 4. Patch runtime URLs (include service ports)

Preferred path (automated):

```bash
./scripts/patch-lb-urls.sh
```

Optional namespace override:

```bash
./scripts/patch-lb-urls.sh <namespace>
```

This script:
- Reads backend/frontend LoadBalancer DNS names
- Patches `app-config` with `FRONTEND_ORIGIN` and `VITE_API_BASE_URL`
- Restarts backend first, then frontend
- Runs quick health checks

Manual fallback:

Important:
- Backend Service is exposed on `:8000`
- Frontend Service is exposed on `:5173`

```bash
kubectl patch configmap app-config -n ci-assignment --type merge -p \
"{\"data\":{\"FRONTEND_ORIGIN\":\"http://$FRONTEND_DNS:5173\",\"VITE_API_BASE_URL\":\"http://$BACKEND_DNS:8000/api\"}}"
```

## 5. Restart one deployment at a time

This cluster can hit pod-capacity limits (`Too many pods`), so do not restart both at once.

Use commit SHA image rollout instead of restart-only rollout (backend then frontend):

```bash
./scripts/rollout-sha-images.sh <your-dockerhub-username>
```

Fallback restart-only flow (if image is already correct):

```bash
kubectl rollout restart deployment/backend -n ci-assignment
kubectl rollout status deployment/backend -n ci-assignment

kubectl rollout restart deployment/frontend -n ci-assignment
kubectl rollout status deployment/frontend -n ci-assignment
```

If you used `./scripts/patch-lb-urls.sh`, this restart sequence is already handled by the script.

## 6. Verify

```bash
# Backend health
curl -i "http://$BACKEND_DNS:8000/api/health"

# Backend CORS for frontend origin
curl -i -H "Origin: http://$FRONTEND_DNS:5173" "http://$BACKEND_DNS:8000/api/health"

# Frontend HTML
curl -i "http://$FRONTEND_DNS:5173"
```

Open in browser:

```text
http://<FRONTEND_DNS>:5173
```

## Quick troubleshooting

### EXTERNAL-IP stays `<pending>`

Your environment may not support `LoadBalancer` or cloud integration is misconfigured.

### `Too many pods` / pods stuck `Pending`

Check:

```bash
kubectl get pods -A -o wide
kubectl describe pod <pending-pod-name> -n ci-assignment
kubectl get node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') -o jsonpath='capacity.pods={.status.capacity.pods}{" allocatable.pods="}{.status.allocatable.pods}{"\n"}'
```

If needed, free capacity or scale node group.

### You accidentally used port 80

Dual LB in this setup is not on port 80. Always use:
- `http://<backend-dns>:8000/api`
- `http://<frontend-dns>:5173`
