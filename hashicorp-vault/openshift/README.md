# HashiCorp Vault (OpenShift)

Same job as on Kubernetes — Vault initialises and unseals itself, and hands
out PostgreSQL passwords that expire on their own. No OLM operator exists for
Vault, so this installs the exact same [bank-vaults](https://github.com/bank-vaults/vault-operator)
Helm chart as Kubernetes, from `../common/chart/`, just with a different
values file.

## What's here

```text
../common/chart/    The vault-operator (installs the operator only)   (wave 30)
../common/tests/    Prereq gate, then a smoke test that writes and reads a secret
values.yaml          OpenShift-specific chart values
config/base/         The Vault server itself, as a Vault resource      (wave 40)
                      - wraps ../../common/config/base and adds
                      platformManagedSecurityContext: true (see Known risk below)
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

## SCC compatibility: platformManagedSecurityContext

Confirmed against a real CRC cluster: without it, the vault-operator sets an
explicit `fsGroup` (and `runAsUser`) on both the Vault pod and the
`vault-configurer` pod, which `restricted-v2` rejects outright —

```text
pods "vault-configurer-..." is forbidden: unable to validate against any
security context constraint: [... restricted-v2: .spec.securityContext.fsGroup:
Invalid value: []int64{1000}: 1000 is not an allowed group ...]
```

`config/base/kustomization.yaml` here patches the Vault CR with
`spec.platformManagedSecurityContext: true`, which tells the operator to
leave the security context unset on both pods so OpenShift's SCC assigns one
dynamically instead — the same idea as stakater-reloader's `isOpenshift`
flag, just exposed through this operator's own CRD rather than a Helm
chart's values.
