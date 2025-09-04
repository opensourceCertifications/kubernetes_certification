#!/bin/bash
set -euo pipefail

JOIN_FILE="/vagrant/worker-join.sh"

# Wait for master to create the join file
while [ ! -f "$JOIN_FILE" ]; do
  echo "Waiting for the join file to be created..."
  sleep 10
done

echo "[worker] Joining the Kubernetes cluster..."

# Execute the join command
sudo bash /vagrant/worker-join.sh
