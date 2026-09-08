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
config/namespace/    The namespace, labelled for GitOps                (wave 30)
config/scc/          A custom SCC + RoleBinding for the two capabilities
                      the operator hardcodes onto the Vault container  (wave 30)
config/base/         The Vault server itself, as a Vault resource      (wave 40)
                      - wraps ../../common/config/base and adds
                      platformManagedSecurityContext: true
```

Two SCC accommodations are needed here, and they're independent of each other
— see the two sections at the end.

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

## SCC compatibility 1/2: the pod's UID and fsGroup

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

## SCC compatibility 2/2: IPC_LOCK and SETFCAP

`platformManagedSecurityContext` stops the operator pinning a UID and fsGroup.
It does **not** stop it adding capabilities — every Vault container it renders
gets

```yaml
securityContext:
  capabilities:
    add: [IPC_LOCK, SETFCAP]
```

and no SCC OpenShift ships permits either one (`restricted-v2` allows only
`NET_BIND_SERVICE`; `anyuid` and friends allow none; only `privileged` allows
everything, which is far too broad). So the StatefulSet can't create a pod at
all:

```text
pods "vault-0" is forbidden: unable to validate against any security context
constraint: [... restricted-v2: .containers[0].capabilities.add: Invalid value:
"IPC_LOCK": capability may not be added ...]
```

Removing the capabilities would be the better fix, and it isn't available on
vault-operator **v1.24.0**. Both routes were tried against the live cluster:

- `spec.skipVaultContainerCapabilities` exists in newer bank-vaults source
  ("stops the operator from adding the IPC_LOCK and SETFCAP capabilities") but
  not in this version's CRD — `oc explain
  vault.spec.skipVaultContainerCapabilities` says *field does not exist*.
- `spec.vaultContainerSpec.securityContext.capabilities.add` is **unioned**
  with the operator's own list, not substituted for it. An empty list was
  ignored; adding `NET_BIND_SERVICE` produced
  `[IPC_LOCK, SETFCAP, NET_BIND_SERVICE]`. There is no way to subtract.

So `config/scc/` grants the capabilities instead, as narrowly as possible:
`vault-ipc-lock` is byte-for-byte `restricted-v2` — no host access, no
privilege escalation, dynamically allocated UID and fsGroup,
`requiredDropCapabilities: [ALL]`, `runtime/default` seccomp — with only
`IPC_LOCK` and `SETFCAP` added to `allowedCapabilities`, and a `RoleBinding`
(not a ClusterRoleBinding) makes it usable by exactly one subject: the `vault`
ServiceAccount in the `vault` namespace, which backs the StatefulSet and
`vault-configurer`. The operator's own pod runs as `vault-operator` and never
touches it.

For what it's worth both capabilities are ones Vault legitimately asks for:
`IPC_LOCK` for `mlock()`, so key material is never swapped to disk, and
`SETFCAP` so the entrypoint can set that capability on the binary. Our config
sets `disable_mlock: true` — raft storage on a container filesystem doesn't
support it — so `IPC_LOCK` goes unused in practice, but the operator adds it
regardless.

Because the SCC is cluster-scoped, `security.openshift.io/SecurityContextConstraints`
is on the AppProject's `clusterResourceWhitelist`
([../../argocd/openshift/bootstrap/appproject.yaml](../../argocd/openshift/bootstrap/appproject.yaml)).
That file is applied by hand during bootstrap, so re-apply it if you're
upgrading an existing cluster:

```bash
oc apply -f argocd/openshift/bootstrap/appproject.yaml
```
