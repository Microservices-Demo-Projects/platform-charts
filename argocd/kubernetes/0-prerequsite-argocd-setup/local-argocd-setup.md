# Local ArgoCD Setup

Quick-test GitOps installation for local clusters (CRC or Kind). For AWS EKS, see multi-tenant/HA setup.

Reference: https://argo-cd.readthedocs.io/en/stable/try_argo_cd_locally/

## Install

Set kubectl context first:
```bash
# Kind
kubectl cluster-info --context kind-local-poc-cluster
```

Install ArgoCD:
```bash
# Create namespace
kubectl create namespace argocd

# Install
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify
kubectl get all,pvc -n argocd

kubectl wait pod --all --for=condition=Ready --namespace=argocd --timeout=120s ; \
kubectl get all,pvc -n argocd

```

## Access UI

**Port forward:**
```bash
nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

Open: `https://localhost:8080/`

**Credentials:**
- Username: `admin`
- Password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

**Stop port-forward:**
```bash
# Method 1: Kill all kubectl port-forward processes (cross-platform)
pkill -f "kubectl port-forward"

# Method 2: Find and kill by process ID
ps aux | grep "kubectl port-forward"
kill <PID>

# Method 3: Using shell jobs (bash/zsh only)
jobs
kill %1
```


## CLI Setup

```bash
# Install CLI (macOS)
brew install argocd

# Get password and login
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
argocd login localhost:8080 --username admin --password $PASSWORD --insecure

# Verify
argocd account list
argocd repo list
argocd app list
```

## Configure Git Access

**HTTPS (Personal Access Token):**
```bash
kubectl create secret generic github-credentials \
  --from-literal=type=git \
  --from-literal=url=https://github.com \
  --from-literal=username=<USERNAME> \
  --from-literal=password=<PERSONAL_ACCESS_TOKEN> \
  -n argocd

kubectl label secret github-credentials argocd.argoproj.io/secret-type=repository -n argocd
```

**SSH:**
```bash
# Generate key (if needed)
ssh-keygen -t ed25519 -f argocd-key -N ""
# Or provide the path of exisitng private key file.

# Create secret
kubectl create secret generic github-ssh \
  --from-literal=type=git \
  --from-literal=url=git@github.com \
  --from-literal=username=git \
  --from-file=sshPrivateKey=argocd-key \
  -n argocd

kubectl label secret github-ssh argocd.argoproj.io/secret-type=repository -n argocd
```

Add public key (`argocd-key.pub`) to GitHub SSH keys.

**Repository-specific credentials:**
```bash
kubectl create secret generic repo-specific \
  --from-literal=type=git \
  --from-literal=url=https://github.com/<USERNAME>/<REPO>.git \
  --from-literal=username=<USERNAME> \
  --from-literal=password=<PERSONAL_ACCESS_TOKEN> \
  -n argocd

kubectl label secret repo-specific argocd.argoproj.io/secret-type=repository -n argocd
```

## Next Steps

- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [Follow the Installation Guide of POC Projects](https://github.com/Microservices-Demo-Projects/gitops-platform-bootstrap)
