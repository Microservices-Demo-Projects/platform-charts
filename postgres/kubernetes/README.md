# PostgreSQL (Kubernetes)

A 3-node PostgreSQL cluster (1 primary, 2 replicas) with automatic failover, TLS on
every connection, and **passwords issued by Vault that expire after an hour**.

Run by [CloudNativePG](https://cloudnative-pg.io/) (CNPG), a CNCF operator.

## What's here

```text
chart/       The CNPG operator (Helm chart)   (wave 30)
values.yaml  Kubernetes-specific chart values

../common/config/   The database cluster + its certificates   (wave 60)
../common/tests/    Prereq gate, then a smoke test using a real Vault password
../manual/          The older Bitnami-chart path - see ../manual/README.md
```

Last wave, because it needs Vault (40) and External Secrets (50) working first.

## Install

Nothing to do — ArgoCD handles it. See the [ArgoCD guide](../../argocd/README.md).

## Verify

```bash
# 3 pods, all Running
kubectl get pods -n postgres

# INSTANCES 3, READY 3, and a PRIMARY named
kubectl get cluster postgres -n postgres
```

## Connecting

CNPG creates three Services — pick based on what you need:

| Service | Use for |
| --- | --- |
| `postgres-rw.postgres.svc.cluster.local:5432` | Reads and writes (the primary) |
| `postgres-ro.postgres.svc.cluster.local:5432` | Read-only (replicas, spreads load) |
| `postgres-r.postgres.svc.cluster.local:5432` | Reads from any instance |

The database is `pocdb`. Get credentials through Vault, not a fixed password — see
the `ExternalSecret` example in the
[External Secrets guide](../../external-secrets/kubernetes/README.md), using
`database/creds/app-ro` or `database/creds/app-rw`.

Every password Vault issues creates a **new PostgreSQL user**, deleted after an
hour. Nothing to rotate, nothing to leak.

## Roles

| Role | Can do |
| --- | --- |
| `app_ro` | Read the `app` schema |
| `app_rw` | Read and write the `app` schema |
| `vault` | Create and drop the temporary users above. Logs in with a certificate, no password. |

## Superuser access

Off by default, on purpose. To turn it on temporarily:

1. Set `enableSuperuserAccess: true` in `../common/config/base/cluster.yaml`
2. Commit and push, let ArgoCD sync
3. The password appears in the `postgres-superuser` Secret
4. **Set it back to `false`** and sync again when you're done

Every toggle is a git commit, so there's a record of when superuser access was open.

Vault deliberately doesn't manage this password: to rotate a superuser's password
Vault would itself need `SUPERUSER`, which is far too much access to grant for a
credential this rarely used.

## Why CNPG and not Bitnami

The `manual/` path uses the Bitnami PostgreSQL chart and still works, but for GitOps
CNPG is a better fit:

- **Bitnami's images broke.** `docker.io/bitnami/postgresql:*` now 404s, and the
  current chart defaults to an unpinned `:latest` — not something you can sync
  repeatably.
- **HA is built in.** The `Cluster` resource handles primary/replica topology,
  failover and replication. No StatefulSet wiring by hand.
- **cert-manager works natively.** Server, client and replication TLS all take
  cert-manager secrets directly, reusing the shared `demo-ca`.
- **Schema and roles are declarative** instead of a hand-run `psql` session.

CNPG is Apache-2.0.

## A bug worth knowing about

The old Bitnami config tried to match Vault's dynamic users with the pg_hba rule
`hostssl all vlt_+ ...`. `vlt_+` isn't valid pg_hba syntax, so it silently matched
nothing — and since pg_hba is first-match-wins, every Vault user fell through to the
catch-all rule instead.

The CNPG config matches by role membership (`+app_ro`, `+app_rw`) instead, which
matches any user that's a member of those roles — exactly what Vault creates.
