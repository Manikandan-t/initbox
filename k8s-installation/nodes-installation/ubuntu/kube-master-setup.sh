#!/bin/bash
# Kubernetes Master Node Setup Script

set -e

echo "[INFO] Updating system and installing prerequisites..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

echo "[INFO] Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[INFO] Loading kernel modules and applying sysctl settings..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "[INFO] Installing containerd..."
sudo apt-get install -y containerd.io

echo "[INFO] Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[INFO] Adding Kubernetes repo and GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

echo "[INFO] Installing kubelet, kubeadm, and kubectl (v1.31.0-1.1)..."
sudo apt-get update
sudo apt-mark unhold kubelet kubeadm kubectl

K8S_VERSION="1.31.0-1.1"
sudo apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet
sudo systemctl start kubelet

echo "[INFO] Initializing Kubernetes control plane..."
CONTROL_PLANE_IP="172.177.31.184"
POD_CIDR="192.168.0.0/16"

sudo kubeadm init \
  --pod-network-cidr=$POD_CIDR \
  --control-plane-endpoint="$CONTROL_PLANE_IP:6443" \
  --apiserver-cert-extra-sans=$CONTROL_PLANE_IP \
  --cri-socket=unix:///var/run/containerd/containerd.sock \
  --v=5

#sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock --control-plane-endpoint "172.177.31.184:6443" --apiserver-cert-extra-sans=172.177.31.184 --v=5

echo "[INFO] Configuring kubeconfig for current user..."
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown "$(id -u):$(id -g)" $HOME/.kube/config
#export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[INFO] Installing Calico CNI..."
kubectl apply -f https://docs.projectcalico.org/v3.25/manifests/calico.yaml

echo "[INFO] If any node remains NotReady, restart containerd..."
sudo systemctl restart containerd

echo "[INFO] To get the join command for worker nodes, run:"
echo "kubeadm token create --print-join-command"