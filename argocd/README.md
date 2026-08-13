# ArgoCD GitOps Automation Guide

Point ArgoCD at this repo and the entire Kubernetes landing zone comes up in the right order, with no manual `vault operator init`/`unseal`, no two-phase `--set clusterSecretStore.required=true` re-install, and no `kubectl patch` after the fact. OpenShift support will be added later as `argocd/openshift/` sibling overlays, without restructuring anything here.

## Layout

```text
argocd/
  kubernetes/
    bootstrap/
      appproject.yaml   # AppProject "platform" - scopes every Application below to this repo + an explicit namespace/cluster-resource allowlist
      root-app.yaml      # app-of-apps: syncing this applies every Application in apps/
    apps/
      cert-manager.yaml                 # wave 10
      cert-manager-config.yaml          # wave 20
      vault-operator.yaml               # wave 30
      external-secrets.yaml             # wave 30
      cloudnative-pg-operator.yaml      # wave 30
      stakater-reloader.yaml            # wave 30
      headlamp.yaml                     # wave 30
      vault-config.yaml                 # wave 40
      external-secrets-config.yaml      # wave 50
      postgres.yaml                     # wave 60
```

Each `Application` uses `syncPolicy.automated: {prune: true, selfHeal: true}`, `CreateNamespace=true`, and `ServerSideApply=true` (required for cert-manager's CRDs, which exceed the client-side-apply annotation size limit). Sequencing between stages comes entirely from `argocd.argoproj.io/sync-wave` plus ArgoCD's health checks - no custom Lua needed for `Certificate`, `ClusterIssuer`, `ClusterSecretStore`, or CNPG's `Cluster` (all have built-in checks). `vault.banzaicloud.com/Vault` has no built-in check, so `hashicorp-vault/config/base/argocd-health-check.yaml` extends `argocd-cm` with one, gating wave 50/60 on Vault actually having elected a raft leader - not just on the CR existing.

Kafka is intentionally **not** wired in yet (`kafka/` is a skeleton, tracked as `❌ To Do` in the root README).

## Sync waves

| Wave | Application(s) | What comes up | Gated by |
| --- | --- | --- | --- |
| 10 | `cert-manager` | cert-manager controller/webhook/cainjector | - |
| 20 | `cert-manager-config` | shared `demo-ca` root CA + PostSync smoke test | cert-manager healthy |
| 30 | `vault-operator`, `external-secrets`, `cloudnative-pg-operator`, `stakater-reloader`, `headlamp` | operators/controllers + any dependency-free config (ESO's own mTLS cert, headlamp's cert+RBAC) | `demo-ca` Ready |

`headlamp` is **Kubernetes-only** - OpenShift has its own native web console, so this Application has no OpenShift equivalent and will be excluded when `argocd/openshift/apps/` is added later.
| 40 | `vault-config` | Vault CR (raft `size: 3`, auto-init/unseal, kv-v2 + database secrets engines, kubernetes auth) + PostSync smoke test | vault-operator + its CRDs installed |
| 50 | `external-secrets-config` | `ClusterSecretStore` + PostSync smoke test | Vault healthy (custom health check) |
| 60 | `postgres` | CNPG `Cluster` (`instances: 3`), superuser `PushSecret`, PostSync smoke test that pulls a live `database/creds/app-ro` lease | `ClusterSecretStore` Valid |

Every PostSync smoke-test Job cleans up its own throwaway namespace/resources on success, and deliberately leaves them behind on failure for debugging.

## Quick start

```bash
kubectl apply -f argocd/kubernetes/bootstrap/appproject.yaml
kubectl apply -f argocd/kubernetes/bootstrap/root-app.yaml
```

Then watch it converge:

```bash
argocd app list
argocd app get platform-root
```

Every component's manual, hand-run install path is still documented and untouched under `<component>/manual/README.md`, for anyone who wants to deploy or troubleshoot a piece individually instead of through ArgoCD.
