# OLM install path — retired, kept for reference

**Nothing syncs this directory.** No ArgoCD Application references it.

These manifests install External Secrets via the community
`external-secrets-operator` OLM `Subscription` instead of the upstream Helm
chart. That was the original OpenShift path; it was replaced by
`../../values.yaml` + `../../../common/chart/` because the operator's image,
`ghcr.io/external-secrets/external-secrets-helm-operator`, publishes only a
`linux/amd64` manifest — on an arm64 node it crashloops inside the Go runtime's
GC under emulation. The chart's operand image is multi-arch, so it works
unchanged on both.

Kept because it's still a valid choice on an amd64-only cluster where OLM
lifecycle management is preferred. To use it, point a wave-30 Application at
this directory instead (with `SkipDryRunOnMissingResource=true`, since
`operatorconfig.yaml` needs a CRD the `Subscription` in the same sync installs)
and drop the chart sources. See
[../../README.md](../../README.md#why-the-helm-chart-and-not-the-olm-operator).
