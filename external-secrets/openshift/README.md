# External Secrets (OpenShift)

Same job as on Kubernetes — copies secrets out of Vault into ordinary
Kubernetes Secrets — but installed via the community **external-secrets-operator**
(OLM Subscription) instead of the upstream Helm chart.

## What's here

```text
config/operator/    OperatorGroup + Subscription + OperatorConfig   (wave 30)

../common/config/certificate/           ESO's mTLS certificate                (wave 30)
../common/config/clustersecretstore/    The ClusterSecretStore - the link to Vault  (wave 50)
../common/tests/                        Prereq gate, then a smoke test that pulls a real secret from Vault
```

## Install

Nothing to do — ArgoCD installs this. See the
[ArgoCD guide](../../argocd/README.md).

Unlike cert-manager-operator, this operator does **not** auto-create a default
CR — `config/operator/operatorconfig.yaml` creates an empty `OperatorConfig`
by hand, which is what actually gets the controller pods running.

## Verify

```bash
# Operator installed successfully?
oc get csv -n external-secrets

# Controller, webhook and cert-controller pods
oc get pods -n external-secrets

# The link to Vault. Must say Valid.
oc get clustersecretstore local-vault-backend
```

If that says `InvalidProviderConfig`, Vault isn't up yet — check Vault first.

## Using it

Same as Kubernetes — see
[../kubernetes/README.md](../kubernetes/README.md#using-it) for the
`ExternalSecret` example and how authentication to Vault works. Nothing about
that changes based on how the controller itself got installed.

## A caveat worth knowing

The operator's own docs describe it as installing "external-secrets
helm-chart based" resources, and its owned CRDs match the upstream project's
API group (`external-secrets.io`) by name — but nothing found while building
this confirms the CRDs are byte-for-byte identical to the ones the Kubernetes
Helm chart installs. `../common/config/` should work unmodified in practice,
but if `ClusterSecretStore`/`Certificate` fail to apply, diff the installed
CRD version against the Kubernetes side before assuming it's a config
mistake.
