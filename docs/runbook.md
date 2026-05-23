# Runbook — Day 2 Operations

Operational guide for common tasks on the EKS Platform.

---

## Table of Contents

- [Access the cluster](#access-the-cluster)
- [Deploy a new version](#deploy-a-new-version)
- [Scale workloads](#scale-workloads)
- [Investigate a pod issue](#investigate-a-pod-issue)
- [Access Grafana](#access-grafana)
- [Roll back a deployment](#roll-back-a-deployment)
- [Upgrade the cluster](#upgrade-the-cluster)
- [Destroy the environment](#destroy-the-environment)

---

## Access the cluster

```bash
# Configure kubectl for dev
aws eks update-kubeconfig --region us-east-1 --name eks-platform-dev

# Verify nodes are healthy
kubectl get nodes -o wide

# Check all pods across namespaces
kubectl get pods -A
```

---

## Deploy a new version

Deployments are handled automatically by the CI/CD pipeline on every push to `main`.

To trigger manually:
```bash
# Update the image tag in the GitOps repo
cd eks-platform
sed -i "s|image: .*eks-platform-app:.*|image: YOUR-ECR-URL/eks-platform-app:NEW-TAG|" \
    gitops/apps/sample-app/deployment.yaml

git add . && git commit -m "ci: deploy NEW-TAG" && git push

# ArgoCD will detect the change and sync within ~3 minutes
# Or force-sync immediately:
argocd app sync sample-app
```

---

## Scale workloads

```bash
# Check current HPA status
kubectl get hpa -n sample-app

# Manually scale (overrides HPA temporarily)
kubectl scale deployment sample-app --replicas=4 -n sample-app

# Check node capacity
kubectl describe nodes | grep -A5 "Allocated resources"
```

---

## Investigate a pod issue

```bash
# See recent events for a pod
kubectl describe pod POD-NAME -n NAMESPACE

# Stream logs
kubectl logs -f POD-NAME -n NAMESPACE

# Logs from a crashed container (previous run)
kubectl logs POD-NAME -n NAMESPACE --previous

# Exec into a running container
kubectl exec -it POD-NAME -n NAMESPACE -- /bin/sh

# Check resource usage
kubectl top pods -n NAMESPACE
kubectl top nodes
```

---

## Access Grafana

```bash
# Port-forward to your local machine
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Open http://localhost:3000
# Username: admin
# Password: retrieve with:
kubectl get secret prometheus-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

---

## Roll back a deployment

```bash
# Via ArgoCD (rolls back to previous git commit)
argocd app rollback sample-app

# Via kubectl (rolls back to previous ReplicaSet)
kubectl rollout undo deployment/sample-app -n sample-app

# Check rollout history
kubectl rollout history deployment/sample-app -n sample-app
```

---

## Upgrade the cluster

```bash
# 1. Update cluster_version in terraform/environments/dev/variables.tf
# 2. Plan and apply
cd terraform/environments/dev
terraform plan
terraform apply

# 3. Update node groups (done automatically by Terraform)
# EKS upgrades control plane first, then node groups

# 4. Verify
kubectl version
kubectl get nodes
```

---

## Destroy the environment

```bash
# Remove all ArgoCD-managed apps first (avoids orphaned cloud resources)
argocd app delete monitoring --cascade
argocd app delete sample-app --cascade

# Destroy Terraform-managed infrastructure
cd terraform/environments/dev
terraform destroy

# Confirm by checking AWS console — verify no lingering ELBs or EBS volumes
```

> ⚠️ NAT Gateways, EBS volumes, and Load Balancers created by Kubernetes controllers
> may not be tracked by Terraform. Delete them manually if `terraform destroy` leaves them behind.
