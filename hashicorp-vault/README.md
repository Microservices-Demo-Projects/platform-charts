# HashiCorp Vault

Stores the platform's secrets, and hands out PostgreSQL passwords that expire on
their own, via the [bank-vaults](https://github.com/bank-vaults/vault-operator)
operator (auto-init/unseal, raft HA, kubernetes auth).

- [Kubernetes install](kubernetes/README.md)
- [OpenShift install](openshift/README.md) — no OLM operator exists for Vault, so
  it installs the same Helm chart via `common/chart/`, just with different values

`common/` holds the vault-operator chart, the `Vault` CR + certificate, and
PreSync/PostSync test Jobs, reused as-is by both platforms since there's no
operator to switch to. `manual/` has hand-install instructions instead of
going through ArgoCD.
