# Issues Report

Date: 14 March 2026
Repository: `ci-assignment`
Scope: Latest code changes + current Terraform-created cluster state

## Executive Summary

The latest refactor that split Terraform into `terraform/eks` and `terraform/ecr` is directionally correct, but there are critical operational risks around Terraform state management and deployment workflow assumptions. The current EKS cluster itself is healthy, but no application or monitoring namespaces/resources are deployed in the currently selected context.

## Environment Snapshot (Observed)

- Current kubectl context: `ci-eks-cluster`
- Namespaces present: `default`, `kube-system`, `kube-public`, `kube-node-lease`
- Application namespace `ci-assignment`: not present
- Monitoring namespace `ci-assignment-monitoring`: not present
- Nodes: 2/2 `Ready`
- StorageClass present: `gp2 (default)`
- PV/PVC currently present: none

---

## Finding 1: No persistent Terraform backend for CI (High)

### Severity
High

### What is wrong
The Terraform stacks (`terraform/eks`, `terraform/ecr`) do not configure a remote backend (such as S3 + DynamoDB lock).

### Evidence
- `terraform/eks/main.tf` has no `backend` block.
- `terraform/ecr/providers.tf` has no `backend` block.
- Workflow runs Terraform on ephemeral GitHub runners:
  - `.github/workflows/terraform-provision.yml` (`init`, `plan`, `apply` in `terraform/eks`)
- `.gitignore` excludes Terraform local state artifacts:
  - `*.tfstate`, `*.tfstate.*`, `**/.terraform/*`, `.terraform.lock.hcl`

### Why it matters
Without remote state, each workflow run starts with a clean local state. Existing infra may not be tracked, which can cause drift, duplicate resource attempts, or apply failures.

### Recommended fix
- Add a remote backend for each stack (`terraform/eks`, `terraform/ecr`) using:
  - S3 bucket for state
  - DynamoDB table for state locking
- Document backend bootstrapping process.
- Keep stack states isolated (separate key paths per stack).

---

## Finding 2: Terraform-created cluster is healthy but app is not deployed (High)

### Severity
High

### What is wrong
The current cluster is up and healthy at the infrastructure layer, but there are no application resources deployed.

### Evidence
- `kubectl get ns` shows only system/default namespaces.
- `kubectl get all -n ci-assignment` returns no resources.
- `kubectl get ns ci-assignment ci-assignment-monitoring --ignore-not-found` returns nothing.
- Nodes are healthy (`Ready`), so this is not a node outage.

### Why it matters
Infra provisioning success can be misinterpreted as application readiness. The platform is not serving traffic until deployment workflows run successfully against this same cluster/context.

### Recommended fix
- Add post-provision verification in workflow:
  - Ensure `ci-assignment` namespace exists or is created
  - Validate backend/frontend deployments become `Available`
- Add a context guard:
  - Print and validate `kubectl config current-context` before deploy.

---

## Finding 3: Manual namespace input conflicts with hardcoded manifest namespaces (High)

### Severity
High

### What is wrong
The manual CD workflow accepts a custom namespace, but the rollout script applies `kube.yaml` where resources are hardcoded to `ci-assignment`.

### Evidence
- Manual input namespace exists in workflow:
  - `.github/workflows/cd-manual-deploy.yml` (`inputs.namespace`, `TARGET_NAMESPACE`)
- Rollout script receives namespace argument:
  - `scripts/rollout-sha-images.sh`
- Script applies `kube.yaml` via kustomize but does not override namespaces:
  - `kubectl apply -k "$TMP_DIR"`
- `kube.yaml` hardcodes namespace values (`namespace: ci-assignment`) for namespaced resources.
- Script then waits for rollout in `TARGET_NAMESPACE`, which may differ from where resources were applied.

### Why it matters
Deployments can fail or hang when using non-default namespace input because resources end up in `ci-assignment` while rollout/status checks target a different namespace.

### Recommended fix
Choose one strategy:
1. Enforce single namespace (`ci-assignment`) in workflow input and script.
2. Make namespaces fully dynamic by adding namespace transformation in kustomize overlay.

---

## Finding 4: Monitoring install can fail when app namespace is missing (Medium)

### Severity
Medium

### What is wrong
Monitoring install script applies app-namespace RBAC and ServiceMonitor resources, but does not guarantee the app namespace exists.

### Evidence
- `monitoring/install-monitoring.sh` applies:
  - `app-namespace-rbac.yaml`
  - `app-infra-alerts.yaml`
  - `backend-servicemonitor.yaml`
- `monitoring/app-namespace-rbac.yaml` is namespaced to `__APP_NAMESPACE__` and binds SA from monitoring namespace.
- In current cluster state, `ci-assignment` does not exist.

### Why it matters
On fresh clusters, monitoring install may fail at the final step even if kube-prometheus itself installed correctly.

### Recommended fix
- Preflight in `install-monitoring.sh`:
  - `kubectl get ns "$APP_NS" || kubectl create ns "$APP_NS"`
- Optionally gate app-specific monitoring manifests with a clear warning when app namespace is absent.

---

## Finding 5: Postgres hostPath PV is fragile for EKS (Medium)

### Severity
Medium

### What is wrong
`kube.yaml` uses a static hostPath PV (`local-storage`) for Postgres data.

### Evidence
- `kube.yaml` defines `PersistentVolume` with:
  - `hostPath: /var/lib/k8s/postgres-data`
  - `storageClassName: local-storage`
- PVC is pinned to same class and named PV.
- Current cluster has default `gp2` StorageClass and no local-storage dynamic provisioner.

### Why it matters
hostPath is node-local and non-portable. In managed EKS, node replacement/rescheduling can break persistence guarantees.

### Recommended fix
- Move Postgres persistence to EBS-backed PVC (`gp2` or `gp3`) with dynamic provisioning.
- For production, consider StatefulSet + managed DB option for stronger durability.

---

## Additional Notes

- No compile/lint/editor diagnostics were reported by workspace error scan at the time of review.
- The Terraform path split itself appears consistently reflected in updated README/workflow paths.

## Suggested Priority Order

1. Implement remote Terraform backend and locking.
2. Fix namespace mismatch behavior in manual CD + rollout script.
3. Add deploy/monitoring preflight checks for namespace existence and context validation.
4. Replace hostPath Postgres persistence with EBS-backed storage.
