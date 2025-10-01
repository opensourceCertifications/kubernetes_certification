#!/bin/bash
set -euo pipefail

KUBE_VERSION=1.33.0

### Initialize Kubernetes cluster
kubeadm init \
  --kubernetes-version=${KUBE_VERSION} \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=$(hostname -I | awk '{print $2}') \
  --ignore-preflight-errors=NumCPU

### Configure kubectl for root and vagrant user
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

### Install CNI plugin (Weave Net)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo
echo "🟢 Master node is set up."
echo "👉 Run the 'kubeadm join ...' command shown below on each worker node:"
kubeadm token create --print-join-command --ttl 0 > /vagrant/worker-join.sh

# Create a script to label nodes after they join
cat << 'EOF' > /vagrant/label-nodes.sh
#!/bin/bash
# Wait for all nodes to join
echo "Waiting for worker nodes to join the cluster..."
for i in {1..180}; do
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready ")
  if [ "$NODE_COUNT" -ge 4 ] && [ "$READY_COUNT" -ge 4 ]; then
    echo "All $READY_COUNT/$NODE_COUNT nodes are ready. Labeling worker nodes..."
    kubectl label node k8s-frontend tier=frontend name=k8s-frontend --overwrite || true
    kubectl label node k8s-backend tier=backend name=k8s-backend --overwrite  || true
    kubectl label node k8s-database tier=database name=k8s-database --overwrite || true
    echo "✅ Node labeling complete!"
    exit 0
  fi
  echo "Waiting... ($READY_COUNT/$NODE_COUNT nodes ready)"
  sleep 10
done
echo "⚠️  Warning: Not all nodes joined after 30 minutes"
EOF

chmod +x /vagrant/label-nodes.sh

# Run the labeling script in background
nohup bash /vagrant/label-nodes.sh > /vagrant/label-nodes.log 2>&1 &

# Wait for Calico to be fully ready
echo "⏳ Waiting for Calico components to be ready..."
sleep 45

# Move calico-kube-controllers to master node
echo "📦 Moving calico-kube-controllers to master node..."
kubectl patch deployment calico-kube-controllers -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/nodeSelector",
    "value": {
      "node-role.kubernetes.io/control-plane": ""
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/tolerations",
    "value": [
      {
        "key": "node-role.kubernetes.io/control-plane",
        "operator": "Exists",
        "effect": "NoSchedule"
      }
    ]
  }
]' || true

# Apply namespace configuration
echo "📁 Creating namespaces and resource quotas..."
if [ -f /vagrant/namespace-layout.yaml ]; then
  kubectl apply -f /vagrant/namespace-layout.yaml
fi

# Wait a bit for namespaces to be ready
sleep 5

# Apply application config data
if [ -f /vagrant/backend-secret.yaml ]; then
  kubectl apply -f /vagrant/backend-secret.yaml
fi
if [ -f /vagrant/app-configmaps.yaml ]; then
  kubectl apply -f /vagrant/app-configmaps.yaml
fi
if [ -f /vagrant/database/mysql-service.yaml ]; then
  kubectl apply -f /vagrant/database/mysql-service.yaml
fi

# Apply deployment configurations
echo "🚀 Creating deployments..."
if [ -f /vagrant/node-affinity-deployments.yaml ]; then
  kubectl apply -f /vagrant/node-affinity-deployments.yaml
fi

# Apply public webserver
if [ -f /vagrant/public-webserver.yaml ]; then
  kubectl apply -f /vagrant/public-webserver.yaml
fi

# Apply services consumed by ingress
if [ -f /vagrant/ingress/services.yaml ]; then
  kubectl apply -f /vagrant/ingress/services.yaml
fi

# Install ingress-nginx controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml

# Wait for ingress controller to become ready
kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=180s || true

# Wait for admission webhook jobs to complete (needed before creating Ingress objects)
kubectl -n ingress-nginx wait --for=condition=complete job/ingress-nginx-admission-create --timeout=180s || true
kubectl -n ingress-nginx wait --for=condition=complete job/ingress-nginx-admission-patch --timeout=180s || true

# Force NodePort exposure with stable ports
kubectl -n ingress-nginx patch svc ingress-nginx-controller --type merge -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":80,"nodePort":30080},{"name":"https","port":443,"targetPort":443,"nodePort":30443}]}}'

#!/bin/bash

# Launch post-setup to finalize ingress after workers join
if [ -f /vagrant/scripts/post-setup.sh ]; then
  nohup bash /vagrant/scripts/post-setup.sh > /vagrant/post-setup.log 2>&1 &
  echo "🛠️  Spawned background post-setup to finalize ingress."
fi

# Copy admin.conf to vagrant shared folder for easy access
echo "📋 Copying kubeconfig to shared folder..."
cp /etc/kubernetes/admin.conf /vagrant/kubeconfig
chmod 644 /vagrant/kubeconfig

echo "✅ Master setup complete with all configurations!"
echo ""
echo "📌 To use kubectl from your host machine:"
echo "   export KUBECONFIG=./kubeconfig"
echo "   kubectl get nodes"
