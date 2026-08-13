# External Secrets Operator

Wrapper Helm chart and GitOps manifests for [`external-secrets/external-secrets`](https://artifacthub.io/packages/helm/external-secrets/external-secrets), pre-configured for mTLS integration with the demo HashiCorp Vault backend.

- For the manual, Helm-only install path, see [`manual/README.md`](manual/README.md).
- For the GitOps (ArgoCD) path, the `chart/` Helm chart (ESO controller, CRDs, and the `external-secrets-tls` mTLS Certificate under `config/base/certificate`) is deployed at sync-wave 30. The `ClusterSecretStore` (`local-vault-backend`) under `config/base/clustersecretstore` is deployed as its own Application at sync-wave 50, after HashiCorp Vault's `kubernetes` auth method and `external-secrets` role are declared at sync-wave 40.
- Unlike the manual path, the GitOps path drops the old two-phase install: there is no second `helm upgrade ... --set clusterSecretStore.required=true` re-run. The `ClusterSecretStore` is always declared and simply waits (and is retried by ArgoCD) until Vault's auth backend is ready.
