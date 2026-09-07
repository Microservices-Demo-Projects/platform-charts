# Reloader

Watches Secrets and ConfigMaps for changes and restarts the pods using them —
needed here because Vault rotates database passwords.

- [Kubernetes install](kubernetes/README.md) — upstream Helm chart
- [OpenShift install](openshift/README.md) — same Helm chart, no operator exists

`common/` holds the Reloader Helm chart, reused as-is by both platforms.
`manual/` has hand-install instructions instead of going through ArgoCD.
