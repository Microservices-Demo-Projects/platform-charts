# Cert-Manager

Wrapper Helm chart and GitOps manifests for [`jetstack/cert-manager`](https://artifacthub.io/packages/helm/cert-manager/cert-manager), including a demo self-signed root CA and issuer.

- For the manual, Helm-only install path, see [`manual/README.md`](manual/README.md).
- For the GitOps (ArgoCD) path, the `chart/` Helm chart is deployed at sync-wave 10, and the demo root CA / issuer resources under `config/` are deployed at sync-wave 20, once cert-manager's CRDs and controllers are ready.
