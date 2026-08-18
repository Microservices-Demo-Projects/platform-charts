# Kubernetes GitOps Platform

This repository contains a collection of "Wrapper" Helm charts and Kustomize overlays used to bootstrap a standardized environment on Kubernetes or OpenShift cluster with all required middleware components required for the POCs and Demo projects.

The goal of this repository is to provide a consistent "Landing Zone" for POC applications, ensuring they have immediate access to various middleware applications / components dealing with cross-cutting concerns such as security, config / secret management, database services, etc., regardless of the underlying Kubernetes cluster type.

> [!WARNING]
> Although this is built for demos and POCs. It follows real security practices — mTLS, certificate
> rotation, dynamic credentials — but always review all configurations before using it for any real production project.


## Platform Architecture

The following diagram shows how the components interact to create a secure, automated environment. Even though this is a Demo/POC environment, it utilizes mTLS, Certificate Rotation, Secret Orchestration, and various other concepts to mimic a production-grade architecture.

![Platform Architecture Diagram](./K8sGitOpsClusterProvisioing.png)

## Components Catalog

| S.No | Component | Purpose | Status |
| --- | --- | --- | --- |
| 1 | [Cert-Manager](./cert-manager/) | Automates TLS certificate issuance and renewal. | ✅ Ready |
| 2 | [HashiCorp Vault](./hashicorp-vault/) | Centralized secret management and dynamic credential generation / rotation. | ✅ Ready |
| 3 | [External Secrets](./external-secrets/) | Syncs secrets from Vault into native Kubernetes Secrets. | ✅ Ready |
| 4 | [PostgreSQL](./postgres/) | Secure, TLS-enabled database with Vault credential creation / rotation. | ✅ Ready |
| 5 | [Stakater Reloader](./stakater-reloader/) | Triggers automatic app restarts when Secrets/ConfigMaps change so that the new config / secret values are loaded into the app. | ✅ Ready |
| 6 | [Headlamp](./headlamp/) | Modern Kubernetes UI (Dashboard) required only for standard Kubernetes clusters. For OpenShift the native UI is used. | ✅ Ready |
| 7 | [Kafka](./kafka/) | Distributed event streaming platform for high-performance data pipelines. | ❌ To Do |



## Before you start

- Ensure you have access to a running Kubernetes / OpenShift cluster. 
  - See my [infra-setup](https://github.com/Microservices-Demo-Projects/infra-setup) repo for instructions to quickly setup:
    - [**Local Kubernetes cluster using KIND**](https://github.com/Microservices-Demo-Projects/infra-setup/tree/main/local-kind-cluster)
    - [**OpenShift using Code Ready Containers (CRC)**](https://github.com/Microservices-Demo-Projects/infra-setup/tree/main/local-openshift-cluster)
    - [**AWS - EKS cluster**](https://github.com/Microservices-Demo-Projects/infra-setup/tree/main/aws-eks-cluster-iac)

- Then ensure you have ArgoCD installed in cluster.
  - See [infra-setup/argocd-setup](https://github.com/Microservices-Demo-Projects/infra-setup/tree/main/argocd-setup) repo for instructions to quickly setup:
    - [**Quick Local Cluster Setup** (*Can be used with KIND or CRC clusters from previous cluster setup point*)](https://github.com/Microservices-Demo-Projects/infra-setup/blob/main/argocd-setup/local-argocd-setup.md)
    - [**HA & Multi Tenant Setup** (*Can be used with AWS-EKS from previous cluster setup point*)](https://github.com/Microservices-Demo-Projects/infra-setup/blob/main/argocd-setup/ha-multi-tenant-argocd-setup.md)

- Additionally it is convinient to also have common CLI utilitites like `oc` \ `kubectl`, `helm`, `kustomize`, `argocd`, `aws`, `Terraform`, etc.

## Install
- A single command like this is all we need to deploy everything:
  - in the right sequence (using ArgoCD Sync Waves) 
  - and with all appropriate configurations / validations using (using ArgoCD Sync Pre/Post Sync Hooks)

- To deploy run one of the below commands based on your cluster:
  - **Kuberenetes Cluster:**
    ```bash
    kubectl apply -f argocd/kubernetes/bootstrap/
    ```
  - **OpenShift Cluster:**
    ```bash
    kubectl apply -f argocd/openshift/bootstrap/
    ```

- After running the apply on the bootstrap manifests wait 10-15 minutes for all apps to go `Synced` and `Healthy`in ArgoCD. Verify this using:
  ```bash
  kubectl get applications -n argocd -w
  ```

That's the whole install. The full details on the sync waves order or troubleshooting or installing components without the bootstrap manifests see → **[./argocd/README.md](./argocd/README.md)**

## Installing without ArgoCD

Every component can be installed by hand with `helm` and `kubectl` — useful for
learning how a piece works, or debugging one in isolation. Each component has a
`manual/README.md` with the steps.

Install them in the order listed in the **[./argocd/README.md](./argocd/README.md)**; in many cases the later ones depend on earlier ones.

## Components Directory Structure

- Every component follows the similar structure:
  ```text
  <component>/
    chart/     Wrapper Helm chart around the upstream chart
    values/    Per-environment value overrides
    config/    Extra resources (custom resources, certificates, RBAC)
    tests/     Prerequisite gate ArgoCD runs before syncing, smoke test after
    manual/    Instructions for installing by hand
  ```

- ArgoCD's own manifests live in [`argocd/`](./argocd/).
