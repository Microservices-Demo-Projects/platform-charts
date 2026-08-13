# Headlamp

Wrapper Helm chart and GitOps manifests for [`kubernetes-sigs/headlamp`](https://github.com/kubernetes-sigs/headlamp), a Kubernetes web UI, pre-configured to serve HTTPS using a certificate issued by Cert-Manager.

> [!NOTE]
> **Kubernetes only.** OpenShift ships its own native web console, so this component has no OpenShift equivalent and won't get an `openshift/` overlay — it's excluded from the OpenShift ArgoCD apps entirely.

- For the manual, Helm-only install path, see [`manual/README.md`](manual/README.md).
- For the GitOps (ArgoCD) path, the `chart/` Helm chart and the `config/` Certificate/RBAC resources are deployed together at sync-wave 30, after cert-manager (wave 10/20) is ready.

## What changed from the manual path

The upstream Headlamp Helm chart repository moved from `headlamp-k8s/headlamp` (now a dead URL, returns 404) to `kubernetes-sigs/headlamp`, and the chart version used here has been bumped from `0.39.0` to `0.44.0`. This bump also exposes a new `probes.scheme` value, which lets the liveness/readiness probe scheme be set to `HTTPS` declaratively — eliminating the manual `kubectl patch` step against the `headlamp` Deployment that older versions of this chart required.
