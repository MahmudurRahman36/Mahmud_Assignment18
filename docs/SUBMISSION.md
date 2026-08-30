# Assignment 18 — Submission

**Student:** Mahmudur Rahman  
**Email:** naas360innovation@gmail.com  
**Date:** August 30, 2026  
**GitHub Repo:** https://github.com/MahmudurRahman36/Mahmud_Assignment18

---

## What Was Built

A complete CI/CD and GitOps pipeline for the Support Chat application — a real-time chat app built with React/Vite on the frontend and Express/TypeScript/Socket.IO on the backend.

### Repository Structure

```
Mahmud_Assignment18/
├── .github/
│   └── workflows/
│       ├── ci-cd-dev.yml      # CI on every push; deploy only on manual trigger
│       ├── ci-cd-stage.yml    # CI on every push; deploy only on manual trigger
│       └── ci-cd-prod.yml     # CI + auto deploy on push to prod branch
├── backend/
│   ├── src/                   # TypeScript/Express/Socket.IO source
│   ├── Dockerfile.dev         # tsx hot-run, dev deps only
│   └── Dockerfile.prod        # multi-stage, compiled JS, non-root user
├── frontend/
│   ├── src/                   # React/Vite source
│   ├── nginx.conf             # prod nginx with security headers
│   ├── nginx.dev.conf         # dev nginx, permissive
│   ├── Dockerfile.dev         # Vite dev build, debug-friendly
│   └── Dockerfile.prod        # Vite prod build, minified, non-root
├── k8s/
│   ├── dev/                   # 1 replica, NodePort 30000
│   ├── stage/                 # 2 replicas, NodePort 30010
│   └── prod/                  # 3 replicas, NodePort 30020
├── argocd/
│   ├── dev-application.yaml   # manual sync
│   ├── stage-application.yaml # manual sync
│   ├── prod-application.yaml  # automated sync, selfHeal
│   ├── namespace.yaml
│   └── bootstrap.sh
└── docs/
    ├── DECISIONS.md           # engineering rationale
    └── SUBMISSION.md          # this file
```

### Git Branches

| Branch | Purpose |
|--------|---------|
| `main`  | Source of truth / documentation |
| `dev`   | Integration branch — CI on push, deploy manually |
| `stage` | Staging branch — CI on push, deploy manually |
| `prod`  | Production branch — CI + auto deploy on push |

---

## Infrastructure Deployed

### Kubernetes Cluster
- **Cloud:** AWS EC2, eu-north-1
- **Instance:** t3.medium (i-0798921d71dc4de73)
- **K8s:** k3s v1.36.4+k3s1
- **Public IP:** 13.60.243.176

### Namespaces
- `chat-dev` — dev environment
- `chat-stage` — staging environment
- `chat-prod` — production environment
- `argocd` — GitOps controller

### ArgoCD
- **URL:** http://13.60.243.176:30082
- **Username:** admin
- **Applications:** chat-dev (manual), chat-stage (manual), chat-prod (automated)

### Application Ports (NodePort)
| Environment | Port | URL |
|------------|------|-----|
| dev | 30000 | http://13.60.243.176:30000 |
| stage | 30010 | http://13.60.243.176:30010 |
| prod | 30020 | http://13.60.243.176:30020 |

---

## Docker Images Built

All images built with `{env}-{git-short-sha}` tagging scheme:

| Image | Tag | Size |
|-------|-----|------|
| mrkolincechatgpt/chat-backend | prod-b1be082, prod-latest | 55.3 MB |
| mrkolincechatgpt/chat-backend | dev-b1be082, dev-latest | 71.9 MB |
| mrkolincechatgpt/chat-frontend | prod-b1be082, prod-latest | 21.2 MB |
| mrkolincechatgpt/chat-frontend | dev-b1be082, dev-latest | 21.1 MB |

---

## GitHub Secrets Required (for CI/CD to run)

These secrets must be added at:  
`GitHub → Mahmud_Assignment18 → Settings → Secrets and variables → Actions`

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | mrkolincechatgpt |
| `DOCKERHUB_TOKEN` | (DockerHub access token) |
| `KUBECONFIG_CONTENT` | (contents of `kubeconfig-k8s.yaml` — saved locally) |

The kubeconfig for the GitHub secret is saved at:  
`E:\4. Training\DevOps\Ostad\Assignment18\kubeconfig-k8s.yaml`

---

## How to Deploy (after secrets are added)

### Dev deployment (manual)
1. Create feature branch: `git checkout -b feature/my-feature dev`
2. Make changes, push
3. Merge to `dev`: create PR, merge (CI runs automatically)
4. Go to GitHub Actions → CI/CD — Dev → Run workflow
5. ArgoCD shows `chat-dev` as OutOfSync; click Sync to confirm

### Stage promotion (manual)
1. Create PR: `dev` → `stage`, merge
2. GitHub Actions → CI/CD — Stage → Run workflow
3. ArgoCD → `chat-stage` → Sync

### Prod promotion (automatic)
1. Create PR: `stage` → `prod`, merge
2. GitHub Actions CI/CD — Prod runs automatically
3. ArgoCD detects new manifest, applies within ~3 minutes
4. No manual intervention needed

---

## Commit History

```
b1be082  fix: add backend and frontend as regular source directories
6b623bb  feat: add frontend and backend source code
5a8552f  feat: initial project structure — frontend, backend, CI/CD, K8s, ArgoCD
ebbffe5  Initial commit
```
