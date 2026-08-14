# Headlamp

Wrapper Helm chart and GitOps manifests for [`kubernetes-sigs/headlamp`](https://github.com/kubernetes-sigs/headlamp), a Kubernetes web UI, pre-configured to serve HTTPS using a certificate issued by Cert-Manager.

> [!NOTE]
> **Kubernetes only.** OpenShift ships its own native web console, so this component has no OpenShift equivalent and won't get an `openshift/` overlay — it's excluded from the OpenShift ArgoCD apps entirely.

- For the manual, Helm-only install path, see [`manual/README.md`](manual/README.md).
- For the GitOps (ArgoCD) path, the `chart/` Helm chart and the `config/` Certificate/RBAC resources are deployed together at sync-wave 30, after cert-manager (wave 10/20) is ready.

## What changed from the manual path

The upstream Headlamp Helm chart repository moved from `headlamp-k8s/headlamp` (now a dead URL, returns 404) to `kubernetes-sigs/headlamp`, and the chart version used here has been bumped from `0.39.0` to `0.44.0`. This bump also exposes a new `probes.scheme` value, which lets the liveness/readiness probe scheme be set to `HTTPS` declaratively — eliminating the manual `kubectl patch` step against the `headlamp` Deployment that older versions of this chart required.


## Verification

Check the status to ensure the pod becomes `READY 1/1`.

### 1. Status & Events

```bash
# General status check
kubectl get pods,svc,certificate -n headlamp

# Check events for recent errors or warnings
kubectl get events -n headlamp --sort-by='.lastTimestamp'

# Check service details
kubectl get svc headlamp -n headlamp -o yaml
```

### 2. Certificate Status

```bash
# Verify certificate status
kubectl get certificate headlamp-tls -n headlamp

# Check for certificate secrets
kubectl get secret headlamp-tls -n headlamp
```

### 3. Logs

```bash
kubectl logs -n headlamp -l app.kubernetes.io/name=headlamp
```

## Access the Dashboard

Use port-forwarding to access the UI securely:

```bash
kubectl port-forward -n headlamp svc/headlamp 8443:443
```

Access at: `https://localhost:8443`

### Authentication

To log in, you need an access token. You can use the default admin service account or create a custom one with restricted access.

#### 1. Default Admin Token

The chart creates a `headlamp` ServiceAccount in the `headlamp` namespace with `cluster-admin` access via the `headlamp-admin` ClusterRoleBinding.

#### 2. Use Custom View-Only Token (Recommended for safety)

For users who only need to view resources without making changes, a restricted service account using the built-in `view` ClusterRole is created.

#### Token Retrieval Methods

There are two primary ways to retrieve a token for authentication.

| Method | Best For | Security | Persistence |
| :--- | :--- | :--- | :--- |
| **Ephemeral Token** | Manual access, debugging, one-time sessions. | **High**: Token has a limited lifetime and is not stored in the cluster. | Short-lived (Default 1h). |
| **Secret-based Token** | Long-running integrations, CI/CD, or older clients. | **Lower**: Token is stored in a permanent Secret resource. | Persistent until deleted. |

##### Approach A: Ephemeral Token (Recommended)

This is the most secure method because the token is generated on the fly and expires automatically.

```bash
# For Admin access:
kubectl create token headlamp --namespace headlamp

# For View-Only access:
kubectl create token headlamp-view --namespace headlamp
```

##### Approach B: Secret-based Token

Use this if you need a persistent token that doesn't expire.

```bash
# 1. Create the Secret (e.g., for headlamp-view)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-view-token
  namespace: headlamp
  annotations:
    kubernetes.io/service-account.name: "headlamp-view"
type: kubernetes.io/service-account-token
EOF

# 2. Retrieve the Token
kubectl get secret headlamp-view-token -n headlamp -o jsonpath="{.data.token}" | base64 --decode
```
