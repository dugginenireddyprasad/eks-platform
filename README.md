# 🚀 Production EKS Platform

> **A battle-tested, production-grade Kubernetes platform on AWS** — provisioned with Terraform, deployed via GitOps (ArgoCD), and fully observable with Prometheus + Grafana.

[![Terraform](https://img.shields.io/badge/Terraform-v1.7-7B42BC?style=flat-square&logo=terraform)](https://terraform.io)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.29-326CE5?style=flat-square&logo=kubernetes)](https://kubernetes.io)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.10-EF7B4D?style=flat-square&logo=argo)](https://argo-cd.readthedocs.io)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/YOUR-USERNAME/eks-platform/ci.yml?style=flat-square&label=CI)](https://github.com/YOUR-USERNAME/eks-platform/actions)

---

## 📋 Table of Contents

- [Problem Statement](#-problem-statement)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Monitoring & Alerting](#-monitoring--alerting)
- [Design Decisions](#-design-decisions)
- [What I Learned](#-what-i-learned)

---

## 🎯 Problem Statement

Most teams provision Kubernetes clusters manually through the AWS console — leading to **configuration drift**, **no audit trail**, and **impossible-to-reproduce environments**.

This project solves that by building a fully automated EKS platform where:
- Every resource is **declared in code** and version-controlled
- Every deployment is **auditable** via GitOps
- Every service is **observable** out of the box — metrics, logs, and alerts from day one

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Account                            │
│                                                                 │
│  ┌──────────────── VPC (10.0.0.0/16) ──────────────────────┐   │
│  │                                                          │   │
│  │  ┌─────────────────┐    ┌─────────────────┐             │   │
│  │  │  Public Subnet   │    │  Public Subnet   │             │   │
│  │  │   us-east-1a    │    │   us-east-1b    │             │   │
│  │  │  [NAT Gateway]  │    │  [NAT Gateway]  │             │   │
│  │  └────────┬────────┘    └────────┬────────┘             │   │
│  │           │                      │                       │   │
│  │  ┌────────▼────────┐    ┌────────▼────────┐             │   │
│  │  │  Private Subnet  │    │  Private Subnet  │             │   │
│  │  │   us-east-1a    │    │   us-east-1b    │             │   │
│  │  │  [Worker Nodes] │    │  [Worker Nodes] │             │   │
│  │  └─────────────────┘    └─────────────────┘             │   │
│  │                                                          │   │
│  │                 ┌──────────────────┐                     │   │
│  │                 │   EKS Control    │                     │   │
│  │                 │      Plane       │                     │   │
│  │                 │  (AWS Managed)   │                     │   │
│  │                 └──────────────────┘                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │   ECR    │  │   S3     │  │ DynamoDB │  │  CloudWatch  │   │
│  │(registry)│  │(tf state)│  │(tf lock) │  │   (logs)     │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────┘

Kubernetes Workloads (inside EKS):
┌──────────────────────────────────────────────────────────────┐
│  ArgoCD  │  Prometheus  │  Grafana  │  Loki  │  App ns      │
└──────────────────────────────────────────────────────────────┘
```

**Traffic flow:**
1. Developer pushes code → GitHub Actions triggers CI
2. CI builds Docker image → pushes to ECR → updates image tag in GitOps repo
3. ArgoCD detects git diff → syncs desired state to cluster
4. Prometheus scrapes all workloads → Grafana dashboards surface metrics
5. Alertmanager fires to Slack on threshold breach

---

## 🛠️ Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Cloud | AWS (EKS, VPC, ECR, S3, IAM) | Most job postings, largest ecosystem |
| IaC | Terraform 1.7 + modules | Reusable, team-friendly, remote state |
| Orchestration | Kubernetes 1.29 (EKS) | Industry standard container platform |
| GitOps | ArgoCD | Declarative, audit trail, self-healing |
| Package Mgmt | Helm 3 | Templated K8s manifests |
| CI | GitHub Actions | Tight GitHub integration, free for public repos |
| Monitoring | Prometheus + Grafana | CNCF standard, huge community |
| Logging | Loki + Promtail | Lightweight, integrates natively with Grafana |
| Alerting | Alertmanager + Slack | PagerDuty-compatible, easy to extend |

---

## 📁 Project Structure

```
eks-platform/
├── terraform/
│   ├── modules/
│   │   ├── vpc/              # VPC, subnets, NAT gateways, route tables
│   │   ├── eks/              # EKS cluster, node groups, OIDC, add-ons
│   │   ├── ecr/              # Container registries per service
│   │   └── iam/              # IRSA roles, policies
│   ├── environments/
│   │   ├── dev/              # Dev cluster config (smaller instance types)
│   │   └── prod/             # Prod cluster config (HA, larger nodes)
│   └── backend.tf            # Remote state: S3 + DynamoDB locking
│
├── helm/
│   ├── apps/
│   │   └── sample-app/       # Helm chart for sample workload
│   └── platform/
│       ├── argocd/           # ArgoCD Helm values
│       ├── prometheus-stack/ # kube-prometheus-stack values
│       └── loki-stack/       # Loki + Promtail values
│
├── gitops/
│   ├── apps/                 # ArgoCD Application manifests
│   └── appset/               # ApplicationSets for multi-env
│
├── .github/
│   └── workflows/
│       ├── ci.yml            # Test → Build → Push to ECR
│       ├── tf-plan.yml       # Terraform plan on PR
│       └── tf-apply.yml      # Terraform apply on merge to main
│
├── monitoring/
│   ├── dashboards/           # Grafana dashboard JSON exports
│   └── alerts/               # Prometheus alerting rules
│
└── docs/
    ├── architecture.md
    ├── runbook.md            # Day-2 operations guide
    └── disaster-recovery.md
```

---

## 🚀 Getting Started

### Prerequisites

```bash
# Required tools
terraform >= 1.7
kubectl >= 1.29
helm >= 3.14
aws-cli >= 2.15
argocd-cli >= 2.10
```

### 1. Bootstrap AWS Backend

```bash
cd terraform/environments/dev

# Initialize remote state backend
terraform init

# Review what will be created
terraform plan -out=tfplan

# Provision VPC + EKS cluster (~12 minutes)
terraform apply tfplan
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name eks-platform-dev

kubectl get nodes  # should see 2–3 worker nodes
```

### 3. Install Platform Components

```bash
# Install ArgoCD
helm upgrade --install argocd \
  helm/platform/argocd/ \
  --namespace argocd --create-namespace

# Bootstrap GitOps — ArgoCD takes over from here
kubectl apply -f gitops/apps/
```

### 4. Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Default credentials (change immediately)
# User: admin  Pass: prom-operator
```

---

## 🔄 CI/CD Pipeline

```
┌──────────┐    push     ┌──────────────────┐   build/push  ┌──────────┐
│Developer │ ──────────► │  GitHub Actions  │ ────────────► │   ECR    │
└──────────┘             │                  │               └──────────┘
                         │  1. Lint & Test  │
                         │  2. Docker Build │    update tag  ┌──────────┐
                         │  3. Push to ECR  │ ────────────► │  GitOps  │
                         │  4. Bump tag     │               │   Repo   │
                         └──────────────────┘               └────┬─────┘
                                                                  │ sync
                                                            ┌─────▼────┐
                                                            │  ArgoCD  │
                                                            │  (EKS)   │
                                                            └──────────┘
```

**Key pipeline features:**
- PR checks run `terraform plan` and output diff as a PR comment
- Docker images tagged with `git SHA` — full traceability
- Automated rollback if liveness probe fails post-deploy
- Slack notification on deploy success / failure

---

## 📊 Monitoring & Alerting

**Dashboards included:**
- Cluster overview (node CPU, memory, pod count)
- Namespace resource consumption
- Application golden signals (latency, traffic, errors, saturation)
- Persistent volume usage with fill-rate prediction

**Alert rules configured:**
```yaml
# Example: Pod crash-looping alert
- alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Pod {{ $labels.pod }} is crash-looping"
```

**Alerts fire to Slack** via Alertmanager webhook integration.

---

## 💡 Design Decisions

**Why ArgoCD over Flux?**
ArgoCD has a richer UI that's excellent for demonstrating GitOps state to non-engineers. For a solo/small-team project, the visibility it provides is worth the slightly higher resource overhead.

**Why Loki over Elasticsearch?**
Loki is dramatically cheaper to run — it only indexes labels, not full log text. For a platform where the primary consumer is Grafana dashboards, Loki + Promtail gives you 90% of the value at 20% of the cost.

**Why separate node groups per environment?**
The dev node group uses `t3.medium` (cost ~$0.04/hr) while prod uses `m5.large`. Keeping them as separate managed node groups lets you independently scale, drain, and update without cross-environment blast radius.

**Why remote state from day one?**
Even in a solo project, S3 + DynamoDB locking builds the habit. It also demonstrates to reviewers that you understand team workflows and wouldn't create state merge conflicts.

---

## 📚 What I Learned

1. **IRSA (IAM Roles for Service Accounts)** is significantly more secure than node-level IAM roles — pods get scoped credentials without sharing across workloads.

2. **ArgoCD app-of-apps pattern** makes bootstrapping a new environment a single `kubectl apply` — massively simplifies cluster replication.

3. **Prometheus `recording rules`** are essential at scale — pre-aggregating expensive queries keeps Grafana dashboards fast even with months of data.

4. **Terraform `moved` blocks** let you refactor module structure without destroying and recreating resources — crucial when reorganizing a real cluster.

5. **EKS managed add-ons vs. self-managed**: AWS-managed add-ons (CoreDNS, kube-proxy, VPC CNI) simplify upgrades but reduce control. Worth the tradeoff for most production clusters.

---

## 🗺️ Roadmap

- [ ] Add Istio service mesh + mTLS between services
- [ ] Integrate Falco for runtime security monitoring
- [ ] Add Velero for cluster backup and DR
- [ ] Implement KEDA for event-driven autoscaling
- [ ] Multi-cluster ArgoCD setup with ApplicationSets

---

## 📄 License

MIT — free to use as a reference or starting point.

---

<div align="center">

**Questions? Open an issue or [reach out on LinkedIn](https://linkedin.com/in/YOUR-PROFILE)**

</div>
