# Reloader (OpenShift)

Same job as on Kubernetes — watches Secrets and ConfigMaps and restarts the
pods using them. No OLM operator exists for Reloader, so this installs the
same [Helm chart](https://github.com/stakater/Reloader) as Kubernetes, from
`../common/chart/`.

## What's here

There's no `values.yaml` here, unlike every other OpenShift path in this
repo. `../common/chart/values.yaml` — the wrapper chart's own defaults — are
already OpenShift-shaped: `isOpenshift: true`, an arbitrary SCC-assigned UID,
and `readOnlyRootFilesystem: true`. It's the *Kubernetes* side
(`../kubernetes/values.yaml`) that overrides those defaults back to
Kubernetes-appropriate settings — so on OpenShift there's nothing to
override; the chart is used as-is.

## Install

Nothing to do — ArgoCD handles it, sourcing `../common/chart` directly with
no values file. See the [ArgoCD guide](../../argocd/README.md).

## Verify

```bash
oc get pods -n stakater-reloader
```

## Known gap vs. Kubernetes

This runs a single replica with no PodDisruptionBudget, unlike the
Kubernetes side's 2-replica HA setup with leader election. Acceptable for a
demo, but worth knowing if you're comparing the two paths.

## Using it

Identical to Kubernetes — see
[../kubernetes/README.md](../kubernetes/README.md#using-it) for the
annotation examples.
