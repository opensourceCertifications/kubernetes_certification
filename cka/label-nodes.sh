#!/bin/bash
# Wait for all nodes to join
echo "Waiting for worker nodes to join the cluster..."
for i in {1..60}; do
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready ")
  if [ "$NODE_COUNT" -eq 4 ] && [ "$READY_COUNT" -eq 4 ]; then
    echo "All 4 nodes are ready. Labeling nodes..."
    kubectl label node k8s-frontend tier=frontend name=k8s-frontend --overwrite
    kubectl label node k8s-backend tier=backend name=k8s-backend --overwrite  
    kubectl label node k8s-database tier=database name=k8s-database --overwrite
    echo "✅ Node labeling complete!"
    exit 0
  fi
  echo "Waiting... ($READY_COUNT/$NODE_COUNT nodes ready)"
  sleep 10
done
echo "⚠️  Warning: Not all nodes joined after 10 minutes"
