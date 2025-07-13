#!/bin/bash
# Kubernetes Worker Node Setup Script for RHEL 9 with containerd

set -e

# --- Section 1: Install Kernel Headers and Modules as USER ---
echo "Step 1: Installing kernel headers as user $(whoami)..."
sudo dnf install -y kernel-devel-"$(uname -r)"

# Load Kernel Modules (requires root for each command)
echo "Step 2: Loading kernel modules..."
sudo modprobe br_netfilter
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo modprobe overlay

# --- Section 2: Run as ROOT USER ---
echo "Step 3: Configuring kernel modules and sysctl settings as root..."
sudo bash -c 'cat > /etc/modules-load.d/kubernetes.conf << EOF
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
overlay
EOF'

sudo bash -c 'cat > /etc/sysctl.d/kubernetes.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF'

sudo sysctl --system

# --- Section 3: Continue as USER ---
echo "Step 4: Disabling swap as user $(whoami)..."
sudo swapoff -a
sudo sed -e '/swap/s/^/#/g' -i /etc/fstab

if free | awk '/^Swap:/ {exit !$2}'; then
  echo "[WARNING] Swap is still enabled. Please check /etc/fstab and swap partitions."
fi

# Install Containerd
echo "Step 5: Installing containerd..."
#sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf makecache
sudo dnf -y install containerd.io

# Configure Containerd
echo "Step 6: Configuring containerd..."
sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
sudo bash -c 'containerd config default > /etc/containerd/config.toml'
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[INFO] Ensuring /etc/cni/net.d exists..."
sudo mkdir -p /etc/cni/net.d

echo "[INFO] Validating containerd is running..."
if ! sudo systemctl is-active --quiet containerd; then
  echo "[ERROR] containerd failed to start. Check logs with: journalctl -xeu containerd"
  exit 1
fi

# --- Section 4: Set Firewall Rules as ROOT ---
echo "Step 7: Configuring firewall rules as root..."
if systemctl is-active --quiet firewalld; then
  echo "[INFO] firewalld is running. Adding Kubernetes ports..."
  sudo firewall-cmd --zone=public --permanent --add-port=10250/tcp
  sudo firewall-cmd --zone=public --permanent --add-port=30000-32767/tcp
  sudo firewall-cmd --reload
else
  echo "[INFO] firewalld is not running. Skipping firewall configuration."
fi

# --- Section 5: Install Kubernetes ---
echo "Step 8: Adding Kubernetes repository..."
sudo tee /etc/yum.repos.d/kubernetes.repo >/dev/null <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

echo "Step 9: Installing Kubernetes packages..."
echo "[INFO] Refreshing package metadata..."
sudo dnf makecache
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

#In some environments (especially with Calico), SELinux can block container networking.
#echo "[INFO] Setting SELinux to permissive mode..."
#sudo setenforce 0
#sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

echo "[INFO] Worker node is ready. Run the kubeadm join command provided by the control plane to complete the setup."