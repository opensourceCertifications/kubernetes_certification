#!/bin/bash
set -euo pipefail

JOIN_FILE="/vagrant/sha"

while [ ! -f "$JOIN_FILE" ]; do
  echo "Waiting for the join file to be created..."
  sleep 10
done

JOIN_CMD=$(cat "$JOIN_FILE")

echo "[worker] Joining the Kubernetes cluster..."

bash /vagrant/worker-join.sh
