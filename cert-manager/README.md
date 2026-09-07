# cert-manager

Issues and auto-renews TLS certificates, and creates `demo-ca` — the shared
certificate authority every other component in this platform trusts.

- [Kubernetes install](kubernetes/README.md) — upstream Helm chart
- [OpenShift install](openshift/README.md) — Red Hat cert-manager Operator (OLM)

`common/` holds the demo-ca certificate chain and PreSync/PostSync test Jobs
shared by both platforms. `manual/` has hand-install instructions instead of
going through ArgoCD.
