#!/usr/bin/env bash
#
# Tear the platform down and leave the cluster as empty as it started.
# ArgoCD itself is never touched.
#
#   ./argocd/kubernetes/teardown.sh
#
# Deleting platform-root on its own is not enough, for two reasons:
#
#  1. It only deletes what ArgoCD tracks. Namespaces created by
#     CreateNamespace=true are not tracked, and neither is anything an operator
#     made for itself: Vault's raft PVCs and unseal keys, cert-manager's issued
#     TLS Secrets, CloudNativePG's data volumes. Leaving Vault's raft data
#     behind breaks the next bootstrap, because a fresh Vault CR then adopts an
#     old cluster it has no unseal keys for. Deleting the namespaces gets all of
#     it; CRDs have been seen to outlive the cascade too, hence the sweep.
#
#  2. It can wedge permanently, and did. An Application declares argocd-cm (to
#     add health checks ArgoCD lacks), so the cascade deleted ArgoCD's own
#     ConfigMap - and the controller reads it on every delete. Every app's
#     finalizer then failed with
#       Unable to delete application resources: cannot apply impersonation:
#       ... application.sync.impersonation.enabled ... configmap not found
#     leaving platform-root in Deleting forever and every lower wave untouched.
#     apps/wave-000 now marks it Delete=false so ArgoCD can't remove it, and the
#     first step below puts it back if an older bootstrap already lost it.
set -euo pipefail

NAMESPACES="postgres external-secrets vault cnpg-system cert-manager stakater-reloader headlamp"

echo "==> Checking ArgoCD can still delete things"
# The controller reads argocd-cm on every delete, so if it's missing then
# finalizeApplicationDeletion fails for every app and nothing is ever torn down:
#   Unable to delete application resources: cannot apply impersonation: ...
#   application.sync.impersonation.enabled ... configmap not found
# apps/wave-000 marks it Delete=false so this can't happen, but recreate it if an
# older bootstrap already lost it - otherwise this script can't make progress.
if ! kubectl get configmap argocd-cm -n argocd >/dev/null 2>&1; then
  echo "    argocd-cm is missing - recreating it so deletes can proceed"
  kubectl create configmap argocd-cm -n argocd
  kubectl label configmap argocd-cm -n argocd app.kubernetes.io/part-of=argocd
fi

echo "==> Clearing in-flight sync operations"
# An app left mid-sync keeps being re-synced instead of finalized, which delays
# its deletion - and since ArgoCD deletes children highest sync-wave first and
# waits for each wave, one slow app holds up every app below it. Marking the
# operation Terminating is what `argocd app terminate-op` does.
for app in $(kubectl get applications -n argocd -o name 2>/dev/null); do
  phase=$(kubectl get "$app" -n argocd -o jsonpath='{.status.operationState.phase}' 2>/dev/null || true)
  if [ "$phase" = "Running" ]; then
    echo "    terminating stuck operation on ${app#*/}"
    kubectl patch "$app" -n argocd --type merge \
      -p '{"status":{"operationState":{"phase":"Terminating"}}}' >/dev/null
  fi
done

echo "==> Deleting platform-root (cascades to every child app)"
kubectl delete application platform-root -n argocd --ignore-not-found --wait=false

echo "==> Waiting up to 5 minutes for the cascade"
for _ in $(seq 1 60); do
  remaining=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$remaining" = "0" ] && break
  sleep 5
done

# Anything still here is wedged on something ArgoCD can't resolve. Dropping the
# finalizer orphans that app's resources, which is harmless from here: the
# namespace and CRD sweeps below remove them anyway.
if kubectl get applications -n argocd --no-headers 2>/dev/null | grep -q .; then
  echo "==> Cascade did not finish; releasing the remaining apps"
  kubectl get applications -n argocd --no-headers | awk '{print $1}' | while read -r app; do
    echo "    releasing $app"
    kubectl patch "application/$app" -n argocd --type merge \
      -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
fi

echo "==> Deleting the platform namespaces (takes the untracked leftovers with them)"
# Deleted in reverse dependency order so operators outlive the resources they
# have to finalize - a CNPG Cluster or Vault CR whose operator is already gone
# keeps its finalizer forever and its namespace hangs in Terminating.
for ns in $NAMESPACES; do
  kubectl delete namespace "$ns" --ignore-not-found --timeout=180s || \
    echo "    WARNING: $ns did not delete cleanly - check 'kubectl get ns $ns -o yaml'"
done

# Observed surviving a cascade that otherwise completed cleanly, so this is not
# just a fallback for the release path above. Deleting a CRD also removes any of
# its custom resources still lying around.
echo "==> Sweeping CRDs"
# `|| true` because grep exits 1 when nothing matches, which pipefail would
# otherwise turn into a failed run.
orphaned_crds=$(kubectl get crd -o name | grep -E \
  'cert-manager\.io|vault\.banzaicloud\.com|external-secrets\.io|postgresql\.cnpg\.io' || true)
if [ -n "$orphaned_crds" ]; then
  echo "$orphaned_crds" | xargs kubectl delete --ignore-not-found --timeout=120s
fi

echo "==> Deleting the AppProject"
kubectl delete -f "$(dirname "$0")/bootstrap/appproject.yaml" --ignore-not-found

echo
echo "==> What's left"
kubectl get applications -n argocd 2>/dev/null || echo "    no Applications"
kubectl get ns -o name | grep -E "$(echo "$NAMESPACES" | tr ' ' '|')" || echo "    no platform namespaces"
echo
echo "Done. Re-bootstrap with: kubectl apply -f argocd/kubernetes/bootstrap/"
