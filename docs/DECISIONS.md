# Engineering Decisions — Support Chat DevOps Pipeline

**Author:** Mahmudur Rahman  
**Date:** August 2026  
**Assignment:** DevOps Practical — CI/CD, Containerization & GitOps Delivery

---

## Branching Strategy

I went with three long-lived branches — `dev`, `stage`, and `prod` — rather than just `main` with short-lived branches. The reason is that this application has three distinct running environments, and I wanted the git history to directly reflect the promotion path. When someone inspects the repo six months from now, they should be able to see exactly when a change moved from integration testing into staging and then into production, without needing any external tracking tool to piece it together.

For merges, I used squash merge for feature branches going into `dev` — this keeps the dev branch history readable without fifteen "fix typo" commits cluttering it. But for `dev → stage` and `stage → prod`, I used regular merge commits. Those promotions are meaningful events in the release lifecycle, and preserving them as explicit merge commits gives you a clear audit trail: you can look at the prod branch log and immediately see which dev build became a prod build and when.

I also set branch protection on `prod` requiring a passing CI status check before any PR can be merged. This means nothing lands in production without the build and type-check passing first.

---

## CI/CD Pipeline Design

The non-negotiable constraint from the brief was that dev and stage deployments must be manually triggered, while production must deploy automatically when a PR is opened (merged) into the prod branch.

For dev and stage, I set up a single workflow file per branch that responds to two triggers: `push` and `workflow_dispatch`. The CI job (install, type-check, build) runs on every push. The deploy job runs **only** when `github.event_name == 'workflow_dispatch'` — meaning a human has to go to the Actions tab and click "Run workflow." The CI running automatically on push is useful because it catches breakages early. But the actual deployment to dev or staging is a deliberate decision, not an automatic consequence of pushing code. This catches situations where the CI passed but the engineer isn't ready to promote the change yet.

For production, I used `on: push: branches: [prod]` with no condition on the deploy job. Once CI passes, the deploy runs automatically. This is safe because the only way something lands on the prod branch is via a merged PR — and that PR was reviewed, CI-checked, and promoted through dev and stage first. By the time it reaches prod, three layers of validation have already happened.

---

## Docker Image Strategy

I produced two distinct images per service: one built from `Dockerfile.dev` and one from `Dockerfile.prod`. The differences are intentional and meaningful, not cosmetic.

For the backend, the dev image runs TypeScript directly via `tsx` — no compile step. This makes the CI pipeline faster and keeps the development feedback loop tight. The prod image uses a multi-stage build: it compiles the TypeScript to JavaScript first, then copies only the compiled output and production dependencies into a clean runtime image. It also runs as a non-root user for security hardening.

For the frontend, the dev image builds the Vite app in `--mode development`, which keeps source maps in the output and skips minification. This makes it easier to debug issues in the dev environment. The prod image runs the default `vite build`, which tree-shakes, minifies, and strips source maps — exactly what you want in production.

For image tagging, I settled on `{env}-{git-short-sha}` — for example `dev-a1b2c3d` or `prod-f7e2b9c`. The environment prefix tells you at a glance which Dockerfile and which configuration was used. The SHA ties it unambiguously to a specific commit. If something goes wrong in production three months from now, you can check the running image tag, run `git show f7e2b9c`, and know exactly what code is in that container. Tags like `latest` give you nothing useful for this kind of traceability.

---

## Kubernetes Manifest Decisions

I chose namespace-based environment separation on a single cluster rather than separate clusters. For a training environment this is the practical choice — separate clusters would require three times the infrastructure for no meaningful isolation benefit at this scale. Each environment gets its own namespace: `chat-dev`, `chat-stage`, `chat-prod`.

The backend is exposed as a `ClusterIP` service in all three environments. The frontend nginx proxies API and Socket.IO traffic to the backend using Kubernetes DNS (`chat-backend-svc:5000`), so the backend never needs direct external access. The frontend is exposed as a `NodePort` — different port per environment (30000/30010/30020) so all three can run simultaneously without port conflicts.

I deliberately left Ingress out, as the brief explicitly excluded it.

Replica counts: dev gets 1 replica (cheap, fast iteration), stage gets 2 replicas (because if you can't catch rolling-update bugs with 2 replicas, you'll hit them in prod), and prod gets 3 replicas for high availability.

---

## ArgoCD GitOps Decisions

I set up three separate ArgoCD Applications — one per environment — each watching a different branch and directory.

For `chat-dev` and `chat-stage`, the `syncPolicy` is empty `{}`. This means ArgoCD watches the repo and shows when the cluster is out-of-sync with git, but it will not apply changes automatically. A human has to click Sync in the ArgoCD UI or run `argocd app sync`. This is the GitOps equivalent of the manual deployment trigger requirement — the human action is now an explicit sync decision rather than a pipeline click.

For `chat-prod`, I set `syncPolicy.automated` with `prune: true` and `selfHeal: true`. Once a PR is merged to prod and the GitHub Actions pipeline commits the updated image tag back to the prod manifests, ArgoCD detects the manifest diff within about three minutes and applies it automatically. No SSH to the cluster, no manual kubectl apply — just git push and the cluster converges. The `selfHeal: true` setting also means that if someone runs a manual `kubectl edit` on a prod resource, ArgoCD will revert it. The git repository is the single source of truth.

---

## What I'd add with more time

The optional bonus section mentioned alerting via a Telegram channel. I'd wire up a Kubernetes event watcher that posts to a Telegram bot when pods crash, ImagePullBackOff, or a deployment gets stuck. This is low-friction and actually useful — you find out about problems before users do, not from a user complaint.
