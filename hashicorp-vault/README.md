# HashiCorp Vault

There are two ways to run Vault in this repo:

- **[`manual/`](manual/README.md)** - the official [`hashicorp/vault`](https://artifacthub.io/packages/helm/hashicorp/vault) Helm chart, run and unsealed by hand. Requires `vault operator init` once, `vault operator unseal` three times, and re-running the unseal step every time the pod restarts. Good for learning how Vault's init/seal/unseal model actually works.
- **GitOps path (`chart/` + `config/`)** - the community-maintained [bank-vaults](https://bank-vaults.dev) `vault-operator`, which manages a `Vault` custom resource and handles init, auto-unseal, and Vault configuration (policies, auth methods, secrets engines) declaratively. Nobody runs `vault operator init`/`unseal` on this path, including after restarts.

## Architecture choice

Vault itself is [BUSL-1.1](https://github.com/hashicorp/vault/blob/main/LICENSE) licensed - free to use for this demo/POC, and still the de-facto standard secrets manager. But the *official* HashiCorp Helm chart only runs Vault server pods; it has no declarative init/unseal/policy automation, which is why the manual path requires the hand-run steps above.

[bank-vaults](https://github.com/bank-vaults/vault-operator) (Apache-2.0, community-maintained - **not** a HashiCorp project) is the most widely-adopted way to close that gap: its `vault-operator` watches a `Vault` CR and drives init, unseal (storing the root token and unseal keys in a Kubernetes Secret, and automatically re-unsealing after every restart), and Vault configuration (policies, the `kubernetes` auth method and roles, secrets engines) without any manual steps. That's what the GitOps path here uses.

## GitOps path layout

- `chart/` - wrapper Helm chart around the bank-vaults `vault-operator` chart (`oci://ghcr.io/bank-vaults/helm-charts/vault-operator`). Deployed at **sync-wave 30**. This only installs the operator Deployment and its CRDs - it does not run Vault itself.
- `config/base/` - the `Vault` custom resource (3-node Raft/integrated-storage quorum) plus its TLS `Certificate`, ServiceAccount, and RBAC. Deployed at **sync-wave 40**, after the operator exists. This is where Vault's policies, `kubernetes` auth role, and secrets engines (`kv` and `database`) are declared, via `spec.externalConfig`.
- `config/kubernetes/` - pass-through Kustomize overlay of `config/base` for standard Kubernetes.
- `values/kubernetes.yaml` - runs the operator with 2 replicas on standard Kubernetes.
- `tests/base/` - a PostSync smoke-test Job that writes/reads/deletes a throwaway KV secret using the operator-generated root token, proving Vault came up unsealed and reachable with no manual intervention.

The `database` secrets engine's connection to Postgres is configured with `verify_connection: false` and a placeholder service name, since the postgres component doesn't exist yet when Vault first syncs; it gets exercised for real once postgres (and its `vault` DB user) exists. See `config/base/vault.yaml` for the exact `TODO` markers.
