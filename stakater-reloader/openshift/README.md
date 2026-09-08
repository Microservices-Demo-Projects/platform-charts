# Reloader (OpenShift)

Same job as on Kubernetes — watches Secrets and ConfigMaps and restarts the
pods using them. No OLM operator exists for Reloader, so this installs the
same [Helm chart](https://github.com/stakater/Reloader) as Kubernetes, from
`../common/chart/`.

## What's here

`../common/chart/values.yaml` — the wrapper chart's own defaults — are
mostly OpenShift-shaped already: `isOpenshift: true`,
`readOnlyRootFilesystem: true`. One thing they can't fix from inside the
chart's own default values file: the vendored `reloader` subchart hardcodes
`reloader.deployment.securityContext.runAsUser: 65534`, which OpenShift's
`restricted-v2` SCC rejects (65534 isn't in the namespace's allocated UID
range) — so pods fail to schedule with `FailedCreate ... must be in the
ranges: [...]`.

Unsetting a subchart's hardcoded default has to come from a genuine
user-supplied values overlay, not from the chart's own bundled
`values.yaml` — Helm's dependency-value merging doesn't treat a `null` set
in a chart's *own* defaults as "remove the subchart's key," only a
`-f`/`helm.valueFiles` layer on top does. `values.yaml` here is exactly that
overlay, wired in via the ArgoCD Application's `helm.valueFiles`.

## Install

ArgoCD sources `../common/chart` plus this directory's `values.yaml` as a
`helm.valueFiles` overlay. See the [ArgoCD guide](../../argocd/README.md).

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
