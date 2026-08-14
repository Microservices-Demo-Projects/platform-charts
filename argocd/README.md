# Deploy everything with ArgoCD

One command and the whole platform comes up: cert-manager, Vault (auto-initialised
and unsealed), External Secrets, PostgreSQL. No manual steps in between.

You need a Kubernetes cluster and ArgoCD already installed in the `argocd` namespace.

## Quick start

```bash
kubectl apply -f argocd/kubernetes/bootstrap/
```

That's two files: the project the apps live in, and `platform-root`, which creates
everything else.

Then watch it come up (10-15 minutes):

```bash
kubectl get applications -n argocd -w
```

You're done when all apps show `Synced` and `Healthy`.

## What comes up, in order

Each app has a `argocd.argoproj.io/sync-wave` number, and ArgoCD finishes one wave
before starting the next.

| Wave | App | What it does |
| --- | --- | --- |
| 0 | `argocd-cm` health checks | Two Lua health checks ArgoCD lacks (see below) |
| 10 | `cert-manager` | Issues TLS certificates for everything below |
| 20 | `cert-manager-config` | Creates `demo-ca`, the shared CA all certs come from |
| 30 | `vault-operator`, `external-secrets`, `cloudnative-pg-operator`, `stakater-reloader` | The operators and controllers |
| 30 | `headlamp` | Web UI (Kubernetes only, no operator involved) |
| 40 | `vault` | The Vault server itself: 3-node HA, auto-unsealed |
| 50 | `external-secrets-config` | Connects External Secrets to Vault |
| 60 | `postgres` | 3-node PostgreSQL with credentials from Vault |

Each app self-heals, so once it's up it stays up.

## Each app checks its own prerequisites

Waves say what order to go in. They don't say whether the previous wave is *usable*
yet — so the four apps with real dependencies check for themselves, with two Jobs
ArgoCD runs for them:

- **Before** anything is applied, a **PreSync gate** waits for what this app needs:
  the CRDs it uses, the operator that reconciles it, `demo-ca`, Vault having a
  leader. It then proves cert-manager's webhook is really answering by sending it a
  throwaway object as a server-side dry-run — admitted by the real webhook, created
  in the cluster as nothing.
- **After** it's synced, a **PostSync smoke test** proves the component actually
  works: Vault really unseals, PostgreSQL really hands out a Vault-issued password.

Either one failing fails the wave, so nothing downstream starts and a broken
component can't be mistaken for a working one. Both live in `<component>/tests/`.

This is what fixed the bootstrap. `Certificate/vault-tls` used to be applied about
three seconds before cert-manager's webhook started serving; it was rejected with
`connection refused`, while the `Vault` resource next to it applied fine — leaving
the operator looping forever on a certificate that would never arrive. The gate
makes that ordering impossible rather than unlikely.

## The two health checks in wave 0

Sync waves only work if ArgoCD can tell whether a resource is healthy. Two kinds it
can't, both fixed in `kubernetes/apps/wave-000-argocd-health-checks.yaml`:

- **A child `Application`.** ArgoCD removed this check in 1.8 version. Without it the waves
  are ignored entirely: all apps get created in the same 15 seconds, Vault tries
  to start before cert-manager can issue its certificate, and the bootstrap fails.
- **A `Vault` resource.** No built-in check exists, so `vault` would look
  Healthy the moment the resource is created — before Vault is unsealed. The check
  waits for Vault to elect a leader.

Both live in that one file on purpose. ArgoCD applies with a single shared field
manager, so if a second app also declared part of `argocd-cm` it would silently
delete these keys.

## If something goes wrong

```bash
kubectl describe application <name> -n argocd   # why it's unhealthy
kubectl get certificate -A                     # certs Ready?
kubectl logs -n vault -l app.kubernetes.io/name=vault-operator
```

Failed gates and smoke tests leave their pods behind on purpose — check their logs.

## Tearing it down

To remove everything — Vault's keys, the database, the namespaces — and get back
to the cluster you started with:

```bash
./argocd/kubernetes/teardown.sh
```

Deleting `platform-root` by hand is *not* enough, and it fails quietly:

- **It leaves things behind.** Only resources ArgoCD tracks get deleted. The
  namespaces aren't tracked (ArgoCD made them via `CreateNamespace=true`), and
  neither is anything an operator made for itself: Vault's raft volumes and unseal
  keys, cert-manager's issued TLS Secrets, PostgreSQL's data. Leftover raft data is
  the nasty one — the next Vault adopts a cluster it has no unseal keys for. The
  script deletes the namespaces, which takes all of it.
- **It used to wedge permanently.** ArgoCD deletes children highest wave first and
  waits for each wave. `argocd-cm` is declared in wave 0, so the cascade deleted
  ArgoCD's own ConfigMap — and the controller reads it on *every* delete, so from
  then on `finalizeApplicationDeletion` failed for every app, `platform-root` sat
  in `Deleting` forever, and no wave below the stuck one was ever touched. Wave 0
  now marks it `Delete=false` so ArgoCD can't remove it; the script also puts it
  back if an older bootstrap already lost it.

The script never touches ArgoCD itself.

## Notes

- Kafka isn't wired in yet.
- OpenShift support will be added later as `argocd/openshift/`.
- Every component can also be installed by hand — see `<component>/manual/README.md`.
