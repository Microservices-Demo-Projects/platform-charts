#!/usr/bin/env bash
#
# Tear the platform down and leave the cluster as empty as it started.
# The OpenShift GitOps operator/ArgoCD itself is never touched.
#
#   ./argocd/openshift/teardown.sh
#
# Deleting platform-root on its own is not enough, for three reasons:
#
#  1. It only deletes what ArgoCD tracks. Namespaces created by
#     CreateNamespace=true are not tracked, and neither is anything an operator
#     made for itself: Vault's raft PVCs and unseal keys, cert-manager's issued
#     TLS Secrets, CloudNativePG's data volumes. Leaving Vault's raft data
#     behind breaks the next bootstrap, because a fresh Vault CR then adopts an
#     old cluster it has no unseal keys for. Deleting the namespaces gets all of
#     it; CRDs have been seen to outlive the cascade too, hence the sweep.
#
#  2. It can wedge permanently if the "platform" AppProject disappears before
#     every child's finalizer resolves - every Application references it via
#     spec.project, so the app controller can't finalize any of them without
#     it (DeletionError: appproject.argoproj.io "platform" not found). The
#     first step below puts it back if it's missing, before deleting anything.
#
#  3. Even with nothing wedged, deletion can just be *slow*: every child app's
#     finalizer runs a sync (to prune its resources) before it can go away, and
#     that sync still runs any PreSync hooks - including the cross-component
#     PreSync gates (see common/tests/base/presync-gate-job.yaml in postgres,
#     vault, cert-manager) that wait on another component's ClusterIssuer or
#     webhook. If that other component is *also* being torn down in the same
#     cascade, the gate keeps failing and the app retries with backoff
#     (~10s/20s/40s/80s/160s) instead of just finishing. The wait-then-release
#     loop below doesn't care why an app is still around, so it resolves this
#     the same way it resolves an actual wedge.
set -euo pipefail

NAMESPACE=openshift-gitops
NAMESPACES="cert-manager-operator cert-manager external-secrets vault postgres stakater-reloader"

echo "==> Checking the platform AppProject exists"
# Every Application references spec.project: platform - if it's gone, no child's
# finalizer can ever resolve (DeletionError: appproject.argoproj.io "platform" not
# found), permanently wedging the whole cascade. Put it back first if missing.
if ! oc get appproject platform -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "    platform AppProject is missing - reapplying it so finalizers can resolve"
  oc apply -f "$(dirname "$0")/bootstrap/appproject.yaml"
fi

echo "==> Clearing in-flight sync operations"
# An app left mid-sync keeps being re-synced instead of finalized, which delays
# its deletion - and since ArgoCD deletes children highest sync-wave first and
# waits for each wave, one slow app holds up every app below it. Marking the
# operation Terminating is what `argocd app terminate-op` does.
for app in $(oc get applications -n "$NAMESPACE" -o name 2>/dev/null); do
  phase=$(oc get "$app" -n "$NAMESPACE" -o jsonpath='{.status.operationState.phase}' 2>/dev/null || true)
  if [ "$phase" = "Running" ]; then
    echo "    terminating stuck operation on ${app#*/}"
    oc patch "$app" -n "$NAMESPACE" --type merge \
      -p '{"status":{"operationState":{"phase":"Terminating"}}}' >/dev/null
  fi
done

echo "==> Deleting platform-root (cascades to every child app)"
oc delete application platform-root -n "$NAMESPACE" --ignore-not-found --wait=false

echo "==> Waiting up to 5 minutes for the cascade"
for _ in $(seq 1 60); do
  remaining=$(oc get applications -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$remaining" = "0" ] && break
  sleep 5
done

# Anything still here is wedged, or stuck retrying a PreSync gate whose dependency
# got torn down first (see point 3 above). Dropping the finalizer orphans that
# app's resources, which is harmless from here: the namespace and CRD sweeps
# below remove them anyway.
if oc get applications -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q .; then
  echo "==> Cascade did not finish; releasing the remaining apps"
  oc get applications -n "$NAMESPACE" --no-headers | awk '{print $1}' | while read -r app; do
    echo "    releasing $app"
    oc patch "application/$app" -n "$NAMESPACE" --type merge \
      -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
fi

echo "==> Deleting the platform namespaces (takes the untracked leftovers with them)"
# Deleted in reverse dependency order so operators outlive the resources they
# have to finalize - a CNPG Cluster or Vault CR whose operator is already gone
# keeps its finalizer forever and its namespace hangs in Terminating.
for ns in $NAMESPACES; do
  oc delete namespace "$ns" --ignore-not-found --timeout=180s || \
    echo "    WARNING: $ns did not delete cleanly - check 'oc get ns $ns -o yaml'"
done

echo "==> Cleaning up the CloudNativePG operator Subscription"
# cloudnative-pg installs into the shared openshift-operators namespace (it
# supports AllNamespaces, so no dedicated namespace/OperatorGroup exists to
# delete) - remove just the Subscription/CSV, never the namespace itself, since
# other cluster-wide operators may also live there.
oc delete subscription cloudnative-pg -n openshift-operators --ignore-not-found
csv=$(oc get csv -n openshift-operators -o name 2>/dev/null | grep -i cloudnative-pg || true)
[ -n "$csv" ] && oc delete "$csv" -n openshift-operators --ignore-not-found

# Observed surviving a cascade that otherwise completed cleanly, so this is not
# just a fallback for the release path above. Deleting a CRD also removes any of
# its custom resources still lying around.
echo "==> Sweeping CRDs"
# `|| true` because grep exits 1 when nothing matches, which pipefail would
# otherwise turn into a failed run.
orphaned_crds=$(oc get crd -o name | grep -E \
  'cert-manager\.io|vault\.banzaicloud\.com|external-secrets\.io|postgresql\.cnpg\.io' || true)
if [ -n "$orphaned_crds" ]; then
  echo "$orphaned_crds" | xargs oc delete --ignore-not-found --timeout=120s
fi

echo "==> Removing the orphaned openshift-gitops-cm ConfigMap"
# An earlier revision of wave-000-argocd-health-checks.yaml put the health-check
# Lua in this ConfigMap before we established that nothing reads it (the
# application-controller runs without --configmap-name, so only argocd-cm
# counts). Git no longer declares it, but it still carries platform-root's
# tracking-id *and* the Delete=false,Prune=false sync-options that revision gave
# it - so ArgoCD wants to prune it, refuses to, and reports platform-root
# permanently OutOfSync on the next bootstrap. It also can't be caught by the
# namespace sweep, since openshift-gitops is never deleted. Hence by hand.
oc delete configmap openshift-gitops-cm -n "$NAMESPACE" --ignore-not-found

echo "==> Deleting the AppProject"
oc delete -f "$(dirname "$0")/bootstrap/appproject.yaml" --ignore-not-found

echo
echo "==> What's left"
oc get applications -n "$NAMESPACE" 2>/dev/null || echo "    no Applications"
oc get ns -o name | grep -E "$(echo "$NAMESPACES" | tr ' ' '|')" || echo "    no platform namespaces"
echo
echo "Done. Re-bootstrap with: oc apply -f argocd/openshift/bootstrap/"
