#!/bin/bash
# Kubernetes Uninstallation Script
set -e

echo "[INFO] Resetting kubeadm (if installed)..."
if command -v kubeadm &> /dev/null; then
    sudo kubeadm reset -f
else
    echo "[INFO] kubeadm not found, skipping reset."
fi

echo "[INFO] Removing Kubernetes directories..."
sudo rm -rf /etc/kubernetes/ /var/lib/etcd /var/lib/kubelet /etc/cni /opt/cni/bin /var/lib/cni

echo "[INFO] Stopping services..."
sudo systemctl stop kubelet || true
sudo systemctl disable kubelet || true

#sudo systemctl stop containerd || true
#sudo systemctl disable containerd || true

echo "[INFO] Removing Kubernetes packages..."
sudo apt-get purge -y kubeadm kubelet kubectl --allow-change-held-packages
sudo apt-get autoremove -y

echo "[INFO] Removing kube config..."
sudo rm -rf $HOME/.kube

echo "[INFO] Cleaning up CNI..."
sudo rm -rf /etc/cni/net.d

# Optional: remove container runtimes and iptables rules
# Uncomment if needed

# echo "[INFO] Removing Docker and containerd..."
# sudo apt-get purge -y docker-ce docker-ce-cli containerd.io
# sudo apt-get autoremove -y
# sudo rm -rf /var/lib/docker /etc/docker
# sudo rm -rf /var/lib/containerd

# echo "[INFO] Clearing iptables rules..."
# sudo iptables -F
# sudo iptables -t nat -F
# sudo iptables -t mangle -F
# sudo iptables -X
# sudo ipvsadm --clear 2>/dev/null || true

echo "[INFO] Disabling swap again (just in case)..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[SUCCESS] Kubernetes has been uninstalled and system cleaned."