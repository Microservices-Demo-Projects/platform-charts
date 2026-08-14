# Kubernetes GitOps Platform

A ready-made starting point for demos and POCs: run one command against an empty
cluster and you get TLS everywhere, a secrets manager, and a HA database with
auto-rotating credentials.

Works on Kubernetes today. OpenShift support is planned.

> [!WARNING]
> Built for demos and POCs. It follows real security practices — mTLS, certificate
> rotation, dynamic credentials — but review everything before using it for anything
> that matters.

## What you get

| Component | What it does |
| --- | --- |
| [cert-manager](./cert-manager/) | TLS certificates, issued and renewed automatically |
| [HashiCorp Vault](./hashicorp-vault/) | Secrets manager. Self-initialising, self-unsealing. |
| [External Secrets](./external-secrets/) | Turns Vault secrets into normal Kubernetes Secrets |
| [PostgreSQL](./postgres/) | 3-node HA database, passwords issued by Vault |
| [Reloader](./stakater-reloader/) | Restarts pods when their secrets change |
| [Headlamp](./headlamp/) | Web UI for the cluster (Kubernetes only) |
| [Kafka](./kafka/) | Planned, not built yet |

Put together, they do something useful: an app asks for a database password, gets
one that's valid for an hour, and restarts itself automatically when it rotates —
with no password stored anywhere in git.

![Platform Architecture Diagram](./K8sGitOpsClusterProvisioing.png)

## Before you start

- A running Kubernetes cluster (Kind works fine — see
  [infra-setup](https://github.com/Microservices-Demo-Projects/infra-setup))
- ArgoCD installed in the `argocd` namespace
- `kubectl` and `helm`

## Install

```bash
kubectl apply -f argocd/kubernetes/bootstrap/
```

Wait 10-15 minutes for all 11 apps to go `Synced` and `Healthy`:

```bash
kubectl get applications -n argocd -w
```

That's the whole install. **[Full details, wave order and troubleshooting →](./argocd/README.md)**

## Installing without ArgoCD

Every component can be installed by hand with `helm` and `kubectl` — useful for
learning how a piece works, or debugging one in isolation. Each component has a
`manual/README.md` with the steps.

Install them in the order listed in the table above; later ones depend on earlier ones.

## How it's laid out

Every component follows the same structure:

```text
<component>/
  chart/     Wrapper Helm chart around the upstream chart
  values/    Per-environment value overrides
  config/    Extra resources (custom resources, certificates, RBAC)
  tests/     Prerequisite gate ArgoCD runs before syncing, smoke test after
  manual/    Instructions for installing by hand
```

ArgoCD's own manifests live in [`argocd/kubernetes/`](./argocd/).
