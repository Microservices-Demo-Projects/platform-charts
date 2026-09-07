# External Secrets

Copies secrets out of Vault into ordinary Kubernetes Secrets, and keeps them in
sync, so apps never need Vault-specific code.

- [Kubernetes install](kubernetes/README.md) — upstream Helm chart
- [OpenShift install](openshift/README.md) — community `external-secrets-operator` (OLM)

`common/` holds the mTLS certificate, the `ClusterSecretStore` (the link to
Vault), and PreSync/PostSync test Jobs shared by both platforms. `manual/` has
hand-install instructions instead of going through ArgoCD. `backup/` is an
unrelated vendored CRD bundle, not part of the GitOps flow.
