# Local ArgoCD Setup (OpenShift)

Quick-test GitOps installation for a local OpenShift cluster (CRC). For AWS EKS /
Kubernetes, see the `kubernetes/` setup docs.

Reference: https://docs.redhat.com/en/documentation/red_hat_openshift_gitops

## Install

Set the `oc` context first:
```bash
oc login -u kubeadmin https://api.crc.testing:6443
```

Install the **Red Hat OpenShift GitOps Operator** via OLM instead of the raw
`install.yaml` used on Kubernetes — this is the supported, secure way to run
ArgoCD on OpenShift (it wires up SCCs and RBAC for you):
```bash
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for the operator's ClusterServiceVersion to succeed
oc get csv -n openshift-operators -w
```

Installing the operator **automatically creates** the `openshift-gitops`
namespace, a default `openshift-gitops` ArgoCD instance in it, and a Route for the
UI — there's no ArgoCD CR to author by hand.

Verify:
```bash
oc get all -n openshift-gitops
oc wait pod --all --for=condition=Ready --namespace=openshift-gitops --timeout=180s
```

## Access UI

**Route (preferred on OpenShift):**
```bash
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```
Open `https://<that-host>/` in a browser.

**Port-forward (fallback):**
```bash
nohup oc port-forward svc/openshift-gitops-server -n openshift-gitops 8080:443 &
```
Open: `https://localhost:8080/`

**Credentials:**
- Username: `admin`
- Password:
  ```bash
  oc -n openshift-gitops get secret openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' | base64 -d
  ```

**Stop port-forward:**
```bash
pkill -f "oc port-forward"
```

## CLI Setup

```bash
# Install CLI (macOS)
brew install argocd

# Port-forward straight to the service, bypassing the OpenShift router -
# logging in through the Route hits `gRPC connection not ready` even with
# --grpc-web, so this is the reliable path for the CLI.
nohup oc port-forward svc/openshift-gitops-server -n openshift-gitops 8080:443 &

# Get password and login
PASSWORD=$(oc -n openshift-gitops get secret openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' | base64 -d)
argocd login localhost:8080 --username admin --password "$PASSWORD" --insecure

# Verify
argocd account list
argocd repo list
argocd app list
```


## Configure Git Access

**HTTPS (Personal Access Token):**
```bash
oc create secret generic github-credentials \
  --from-literal=type=git \
  --from-literal=url=https://github.com \
  --from-literal=username=<USERNAME> \
  --from-literal=password=<PERSONAL_ACCESS_TOKEN> \
  -n openshift-gitops

oc label secret github-credentials argocd.argoproj.io/secret-type=repository -n openshift-gitops
```

**SSH — `secret-type=repository` (one secret per exact repo):**

`url` must be the **exact clone URL of this repo**, not just `git@github.com` — a
`argocd.argoproj.io/secret-type=repository` secret is matched by ArgoCD against
the `repoURL` used in each `Application`/`AppProject` (e.g.
`spec.source.repoURL` in `root-app.yaml`), and a bare host doesn't match anything.

```bash
# Generate key (if needed)
ssh-keygen -t ed25519 -f argocd-key -N ""
# Or provide the path of an existing private key file.

# Create secret
oc create secret generic github-ssh \
  --from-literal=type=git \
  --from-literal=name=github-ssh \
  --from-literal=project=default \
  --from-literal=url=git@github.com:<ORG>/<REPO>.git \
  --from-literal=username=<USERNAME> \
  --from-file=sshPrivateKey=<path-to-private-key> \
  -n openshift-gitops

oc label secret github-ssh argocd.argoproj.io/secret-type=repository -n openshift-gitops
```

For example, for this repo:
```bash
oc create secret generic github-ssh \
  --from-literal=type=git \
  --from-literal=name=github-ssh \
  --from-literal=project=default \
  --from-literal=url=git@github.com:Microservices-Demo-Projects/gitops-platform-bootstrap.git \
  --from-literal=username=sriram-ponangi \
  --from-file=sshPrivateKey=/Users/sriram/.ssh/sriram_github_id_ed25519 \
  -n openshift-gitops

oc label secret github-ssh argocd.argoproj.io/secret-type=repository -n openshift-gitops
```

Add public key (`argocd-key.pub`) to GitHub SSH keys.

**SSH — `secret-type=repo-creds` (credential template for every repo under a prefix):**

Unlike `secret-type=repository`, `url` here *is* a bare host/prefix, not an exact
clone URL — ArgoCD applies these credentials to any repo whose `repoURL` starts
with this prefix, so one secret covers every repo under that GitHub org/user
without adding a new secret per repo.

```bash
oc create secret generic github-ssh-creds \
  --from-literal=type=git \
  --from-literal=url=git@github.com:<ORG>/ \
  --from-literal=username=<USERNAME> \
  --from-file=sshPrivateKey=<path-to-private-key> \
  -n openshift-gitops

oc label secret github-ssh-creds argocd.argoproj.io/secret-type=repo-creds -n openshift-gitops
```

For example, to cover every repo under this org:
```bash
oc create secret generic github-ssh-creds \
  --from-literal=type=git \
  --from-literal=url=git@github.com:Microservices-Demo-Projects/ \
  --from-literal=username=sriram-ponangi \
  --from-file=sshPrivateKey=/Users/sriram/.ssh/sriram_github_id_ed25519 \
  -n openshift-gitops

# OR env just --from-literal=url=git@github.com like: 
oc create secret generic github-ssh-creds \
  --from-literal=type=git \
  --from-literal=url=git@github.com \
  --from-literal=username=sriram-ponangi \
  --from-file=sshPrivateKey=/Users/sriram/.ssh/sriram_github_id_ed25519 \
  -n openshift-gitops

oc label secret github-ssh-creds argocd.argoproj.io/secret-type=repo-creds -n openshift-gitops
```

**Repository-specific credentials (HTTPS, `secret-type=repository`):**

Same exact-URL matching as the SSH `secret-type=repository` case above, but over
HTTPS with a username/PAT instead of an SSH key.

```bash
oc create secret generic repo-specific \
  --from-literal=type=git \
  --from-literal=url=https://github.com/<USERNAME>/<REPO>.git \
  --from-literal=username=<USERNAME> \
  --from-literal=password=<PERSONAL_ACCESS_TOKEN> \
  -n openshift-gitops

oc label secret repo-specific argocd.argoproj.io/secret-type=repository -n openshift-gitops
```

## Next Steps

- [OpenShift GitOps Docs](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops)
- [Follow the Installation Guide of POC Projects](https://github.com/Microservices-Demo-Projects/gitops-platform-bootstrap)
