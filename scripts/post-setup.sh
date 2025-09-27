#!/bin/bash
set -euo pipefail

# This script runs in background from setup-master.sh
# It finalizes ingress-nginx readiness and applies ingress routes once ready.

echo "[post-setup] Starting ingress finalization..."

wait_for() {
  local desc=$1; shift
  # Preserve quoting so complex commands (e.g., bash -lc "...") stay intact
  local cmd=("$@")
  local tries=120
  local sleep_s=5
  for ((i=1; i<=tries; i++)); do
    if "${cmd[@]}"; then
      echo "[post-setup] ${desc} ready"
      return 0
    fi
    echo "[post-setup] waiting for ${desc}... (${i}/${tries})"
    sleep ${sleep_s}
  done
  echo "[post-setup] WARNING: timeout waiting for ${desc}"
  return 1
}

# Ensure kubeconfig is usable (root already has /root/.kube/config from setup)
export KUBECONFIG=/etc/kubernetes/admin.conf

# Wait for worker nodes to join and be Ready, then label them
desired_nodes=4
for i in {1..180}; do
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || true)
  READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
  if [ "$NODE_COUNT" -ge "$desired_nodes" ] && [ "$READY_COUNT" -ge "$desired_nodes" ]; then
    echo "[post-setup] All $READY_COUNT/$NODE_COUNT nodes Ready. Applying labels..."
    kubectl label node k8s-frontend name=k8s-frontend tier=frontend --overwrite || true
    kubectl label node k8s-backend name=k8s-backend tier=backend --overwrite || true
    kubectl label node k8s-database name=k8s-database tier=database --overwrite || true
    break
  fi
  echo "[post-setup] waiting for nodes Ready... ($READY_COUNT/$NODE_COUNT)"
  sleep 10
done

# Wait for controller deployment to be Available
kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=10m || true

# Wait for admission jobs to complete (they set up TLS + webhook)
kubectl -n ingress-nginx wait --for=condition=complete job/ingress-nginx-admission-create --timeout=10m || true
kubectl -n ingress-nginx wait --for=condition=complete job/ingress-nginx-admission-patch --timeout=10m || true

# Wait for the admission service endpoints to exist
if ! wait_for "ingress admission endpoints" bash -lc "[[ -n \$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null) ]]"; then
  echo "[post-setup] Admission endpoints still not ready; will temporarily disable validating webhook to proceed."
  kubectl delete validatingwebhookconfiguration ingress-nginx-admission || true
fi

# Apply ingress routes with retries until success
if [ -f /vagrant/ingress/ingress-routes.yaml ]; then
  for i in {1..60}; do
    if kubectl apply -f /vagrant/ingress/ingress-routes.yaml; then
      echo "[post-setup] Ingress routes applied."
      kubectl get ingress -A || true
      # Wait for backend services to have endpoints
      wait_for "frontend endpoints" bash -lc "[[ -n \$(kubectl -n frontend get endpoints frontend-svc -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null) ]]"
      wait_for "backend endpoints"  bash -lc "[[ -n \$(kubectl -n backend  get endpoints backend-svc  -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null) ]]"
      wait_for "public endpoints"   bash -lc "[[ -n \$(kubectl -n default  get endpoints public-web-service -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null) ]]"
      exit 0
    fi
    echo "[post-setup] Ingress apply failed (attempt $i). Retrying in 10s..."
    sleep 10
  done
  echo "[post-setup] ERROR: Failed to apply ingress routes after retries"
fi

exit 0
