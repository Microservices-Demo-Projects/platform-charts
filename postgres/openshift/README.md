# PostgreSQL (OpenShift)

Same job as on Kubernetes — a 3-node HA PostgreSQL cluster with Vault-issued,
hour-lived passwords — but installed via the certified **CloudNativePG**
operator (OLM Subscription) instead of the upstream Helm chart.

## What's here

```text
config/operator/    Subscription for the cloudnative-pg package   (wave 30)

../common/config/   The database cluster + its certificates       (wave 60)
../common/tests/    Prereq gate, then a smoke test using a real Vault password
```

Last wave, because it needs Vault (40) and External Secrets (50) working first
— same ordering as Kubernetes.

## Install

Nothing to do — ArgoCD installs this. See the
[ArgoCD guide](../../argocd/README.md).

The Subscription installs into `openshift-operators` and relies on the
`global-operators` OperatorGroup OpenShift already provides there — no custom
OperatorGroup needed, since this package supports `AllNamespaces`.

**Package name matters:** use `cloudnative-pg` (the upstream CNCF project),
not `cloud-native-postgresql` (a separate, EDB-owned certified package whose
CRDs live under a different API group, `postgresql.k8s.enterprisedb.io`, and
are not compatible with the `Cluster` manifests in `../common/config/base/`).

## Verify

```bash
# Operator installed successfully?
oc get csv -n openshift-operators

# 3 pods, all Running
oc get pods -n postgres

# INSTANCES 3, READY 3, and a PRIMARY named
oc get cluster postgres -n postgres
```

## Everything else

Connecting, roles, superuser access, and why CNPG over Bitnami are all
identical to the Kubernetes install — see
[../kubernetes/README.md](../kubernetes/README.md). Only how the operator
itself gets installed differs.
