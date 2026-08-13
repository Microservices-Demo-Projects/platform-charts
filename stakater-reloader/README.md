# Stakater Reloader

Wrapper around the official [`stakater/reloader`](https://github.com/stakater/Reloader) chart. Reloader watches ConfigMaps and Secrets and triggers rolling restarts of workloads that reference them when their contents change.

- **Manual installation**: see [manual/README.md](manual/README.md).
- **GitOps (ArgoCD)**: this component is deployed at **sync wave 30** as a standalone controller. It has no downstream `config/` stage to gate — it is installed once and runs continuously in the background reloading workloads across the cluster.

See `chart/` for the Helm chart (with OpenShift-default `values.yaml`) and `values/kubernetes.yaml` for the standard-Kubernetes override values (disables OpenShift mode, runs 2 HA replicas with leader election, and adds a PodDisruptionBudget).
