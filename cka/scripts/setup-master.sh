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
