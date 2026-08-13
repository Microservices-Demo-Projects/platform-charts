# Kafka

Status: planned, not yet implemented.

This component will provide Kafka on Kubernetes/OpenShift via the [Strimzi Kafka Operator](https://strimzi.io/) (CNCF project, Apache-2.0 licensed). Once built, it will follow the same layout as the other components in this repo: `manual/` for manual installation steps, `chart/` for the wrapper Helm chart, `values/` for environment value overrides, `config/{base,kubernetes}` for Kustomize manifests, and `tests/{base,kubernetes}` for smoke tests.

No chart, CRs, or manifests exist yet — this is a placeholder skeleton only.
