# PostgreSQL

Two independent deployment mechanisms for PostgreSQL, kept side by side:

- **`manual/`** -- the original, hand-run path: a wrapper Helm chart around the [Bitnami `postgresql`](https://artifacthub.io/packages/helm/bitnami/postgresql) chart. Unchanged, still valid. See [`manual/README.md`](manual/README.md).
- **GitOps (ArgoCD) path** -- `chart/` installs the [CloudNativePG](https://cloudnative-pg.io/) (CNPG) operator at sync-wave 30; `config/` declares a CNPG `Cluster` custom resource (the actual PostgreSQL instance) at sync-wave 60, once the operator's CRDs and controller are ready.

## Why CNPG instead of Bitnami for the GitOps path

- **Broken upstream images**: the Bitnami `postgresql` chart's `docker.io/bitnami/postgresql:*` image references now 404 -- only the frozen `bitnamilegacy/postgresql:*` tags or the OCI `registry-1.docker.io/bitnamicharts/postgresql` chart still resolve, and even that current chart renders an unpinned `:latest` tag by default. None of that is acceptable for a repeatable GitOps sync.
- **Native HA**: CNPG's `Cluster` CRD manages primary/replica topology, failover, and streaming replication declaratively -- no separate StatefulSet/replication wiring needed.
- **cert-manager-native TLS**: `Cluster.spec.certificates` takes cert-manager-issued secrets directly for server, client-CA, and replication TLS, reusing this platform's shared `demo-ca` ClusterIssuer instead of a chart-specific TLS story.
- **Declarative bootstrap SQL**: `spec.bootstrap.initdb.postInitApplicationSQL` and `spec.managed.roles` replace hand-run `psql` sessions for schema/role setup, and also let us fix a real bug in the old config (see below).

CloudNativePG is a CNCF project, licensed Apache-2.0.

## The postgres-root-password flow is now PUSH, not PULL

The old manual path had an `ExternalSecret` *pull* the root password from Vault (`kv/db/postgres-root`) before Postgres could even start -- a circular boot-order dependency, since Postgres can't come up without a password that depends on Vault, and the whole point of Postgres+Vault integration is Vault reading *from* Postgres.

The GitOps path breaks that cycle: CNPG generates and owns its own superuser credential (`postgres-superuser` secret, auto-created because `enableSuperuserAccess: true` and no `superuserSecret` is set), and an External Secrets Operator `PushSecret` (`config/base/pushsecret.yaml`) *pushes* that password to Vault at `kv/db/postgres-root` instead. Postgres never waits on Vault to boot.

## The pg_hba bug fix

The old `manual/values.yaml` pg_hba config had two `hostssl all vlt_+ ...` lines meant to match Vault-issued dynamic users (`vlt_app_ro_*`, `vlt_app_rw_*`) by username prefix. `vlt_+` is not valid pg_hba glob syntax, so those rules never matched anything -- and since pg_hba is first-match-wins with no fallthrough on a failed match, every Vault-issued user actually fell through to the final catch-all rule instead. The new `config/base/cluster.yaml` fixes this using PostgreSQL's `+role` role-membership syntax (`+app_ro`, `+app_rw`), which matches any role that is a *member* of `app_ro`/`app_rw` -- exactly what Vault's `GRANT app_ro TO "vlt_app_ro_{{name}}"` creation statements produce.

## Layout

```
postgres/
  manual/    Bitnami-chart-based manual install path (unchanged)
  chart/     Wrapper Helm chart installing the CNPG operator (wave 30)
  values/    Environment-specific values for chart/
  config/    CNPG Cluster CR + TLS certificates + PushSecret (wave 60)
  tests/     ArgoCD PostSync smoke test
```

See [`manual/README.md`](manual/README.md) for the Bitnami path's full instructions, including the Phase 1/3 SQL and Vault database-secrets-engine setup this GitOps path's `cluster.yaml` and the parallel `hashicorp-vault` component's `Vault` CR now automate.
