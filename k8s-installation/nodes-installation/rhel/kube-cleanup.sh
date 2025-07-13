#!/bin/bash
# Kubernetes Uninstallation Script for RHEL 9 / CentOS Stream 9

set -e

echo "[INFO] Resetting kubeadm (if installed)..."
if command -v kubeadm &> /dev/null; then
    sudo kubeadm reset -f
else
    echo "[INFO] kubeadm not found, skipping reset."
fi

echo "[INFO] Stopping kubelet service..."
sudo systemctl stop kubelet || true
sudo systemctl disable kubelet || true

# Preserving containerd - skipping stop/disable

echo "[INFO] Removing Kubernetes directories..."
sudo rm -rf /etc/kubernetes/ /var/lib/etcd /var/lib/kubelet /etc/cni /opt/cni/bin /var/lib/cni

echo "[INFO] Removing kube config..."
sudo rm -rf $HOME/.kube

echo "[INFO] Cleaning up CNI config..."
sudo rm -rf /etc/cni/net.d

echo "[INFO] Removing Kubernetes packages (keeping containerd)..."
sudo dnf remove -y kubeadm kubelet kubectl || true

# Optional: if installed from custom repo
# sudo dnf remove -y kubernetes1.31*

echo "[INFO] Cleaning up systemd unit files..."
if [ -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf ]; then
    sudo rm -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
fi
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Optional: remove iptables rules
# echo "[INFO] Clearing iptables rules..."
# sudo iptables -F
# sudo iptables -t nat -F
# sudo iptables -t mangle -F
# sudo iptables -X
# sudo ipvsadm --clear 2>/dev/null || true

echo "[INFO] Disabling swap (again, just in case)..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[INFO] Running autoremove to clean up orphan packages..."
sudo dnf autoremove -y

echo "[SUCCESS] Kubernetes components removed. Containerd retained."