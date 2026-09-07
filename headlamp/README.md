# Headlamp

A web UI for the cluster — browse pods, read logs, check why something's failing.
Served over HTTPS with a certificate from the shared `demo-ca`.

**Kubernetes only.** OpenShift has its own built-in console, so this component
has no OpenShift path — see [kubernetes/README.md](kubernetes/README.md).

`common/` holds its TLS certificate and RBAC — kept separate from `kubernetes/`
for consistency with the rest of the repo, even though there's only one
consumer today. `manual/` has hand-install instructions instead of going
through ArgoCD.
