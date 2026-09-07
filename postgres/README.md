# PostgreSQL

A 3-node PostgreSQL cluster (1 primary, 2 replicas) with automatic failover, TLS
on every connection, and passwords issued by Vault that expire after an hour.
Run by [CloudNativePG](https://cloudnative-pg.io/) (CNPG), a CNCF operator.

- [Kubernetes install](kubernetes/README.md) — CNPG via its Helm chart
- [OpenShift install](openshift/README.md) — the certified `cloudnative-pg` operator (OLM)

`common/` holds the `Cluster` CR, its certificates, and PreSync/PostSync test
Jobs shared by both platforms — CNPG's CRDs are identical regardless of how the
operator itself got installed. `manual/` has the older Bitnami-chart path.
