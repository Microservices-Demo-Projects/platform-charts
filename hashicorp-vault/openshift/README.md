# HashiCorp Vault (OpenShift)

Same job as on Kubernetes — Vault initialises and unseals itself, and hands
out PostgreSQL passwords that expire on their own. No OLM operator exists for
Vault, so this installs the exact same [bank-vaults](https://github.com/bank-vaults/vault-operator)
Helm chart as Kubernetes, from `../common/chart/`, just with a different
values file.

## What's here

```text
../common/chart/    The vault-operator (installs the operator only)   (wave 30)
../common/config/   The Vault server itself, as a Vault resource      (wave 40)
../common/tests/    Prereq gate, then a smoke test that writes and reads a secret
values.yaml          OpenShift-specific chart values
```

## Install

Nothing to do — ArgoCD handles it. See the [ArgoCD guide](../../argocd/README.md).

## Verify

```bash
# 3 vault pods, all Running
oc get pods -n vault

# Has Vault elected a leader? A name here means it's initialised and unsealed.
oc get vault vault -n vault -o jsonpath='{.status.leader}'
```

## Everything else

Getting the root token, what Vault is configured with, and why the operator
instead of HashiCorp's own chart are all identical to the Kubernetes install
— see [../kubernetes/README.md](../kubernetes/README.md).

## Known risk: SCC compatibility is unverified

Neither the vault-operator chart nor the `Vault` CR it reconciles
(`../common/config/base/vault.yaml`) sets an explicit `securityContext` or
`runAsUser` anywhere — that's the shape OpenShift's `restricted-v2` SCC
expects (an arbitrary UID it assigns itself), so this is likely fine. It has
not been possible to confirm against a real OpenShift/CRC cluster while
building this. If pods fail to schedule or start, check `oc get events -n
vault` for an SCC admission denial first.
