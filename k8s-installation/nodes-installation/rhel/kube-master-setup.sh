#!/bin/bash
# Kubernetes Master Node Setup Script for RHEL 9 with containerd

set -e

# --- Section 1: Install Kernel Headers and Modules as USER ---
echo "Step 1: Installing kernel headers as user $(whoami)..."
sudo dnf install -y kernel-devel-$(uname -r)

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
sudo dnf install -y dnf-plugins-core
#sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf makecache
sudo dnf mark install containerd.io

# Configure Containerd
echo "Step 6: Configuring containerd..."
sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
sudo bash -c 'containerd config default > /etc/containerd/config.toml'
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[INFO] Ensuring /etc/cni/net.d exists..."
sudo mkdir -p /etc/cni/net.d

# --- Section 4: Set Firewall Rules as ROOT ---
echo "Step 7: Configuring firewall rules as root..."
if systemctl is-active --quiet firewalld; then
  echo "[INFO] firewalld is running. Adding Kubernetes ports..."
  echo "[INFO] Configuring firewall..."
  sudo firewall-cmd --zone=public --permanent --add-port=6443/tcp
  sudo firewall-cmd --zone=public --permanent --add-port=2379-2380/tcp
  sudo firewall-cmd --zone=public --permanent --add-port=10250/tcp
  sudo firewall-cmd --zone=public --permanent --add-port=10251/tcp
  sudo firewall-cmd --zone=public --permanent --add-port=10252/tcp
  sudo firewall-cmd --zone=public --permanent --add-port=10255/tcp
  sudo firewall-cmd --zone=public --permanent --add-port=5473/tcp
  sudo firewall-cmd --reload
else
  echo "[INFO] firewalld is not running. Skipping firewall configuration."
fi

# --- Section 5: Install Kubernetes ---
echo "Step 8: Adding Kubernetes repository..."
sudo bash -c 'cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF'

echo "Step 9: Installing Kubernetes packages..."
echo "[INFO] Refreshing package metadata..."
sudo dnf makecache
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# --- Section 6: Kubernetes Initialization ---
echo "Step 10: Pulling Kubernetes images..."
sudo kubeadm config images pull

echo "Step 11: Initializing Kubernetes Control Plane..."
if [ -f /etc/kubernetes/admin.conf ]; then
  echo "[INFO] Kubernetes is already initialized. Skipping 'kubeadm init'."
else
  echo "Step 11: Initializing Kubernetes Control Plane..."
  if sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=/var/run/containerd/containerd.sock \
     | tee /var/log/kubeadm-init.log; then
      echo "[INFO] Kubernetes control plane initialized."
  else
      echo "[ERROR] kubeadm init failed. Check /var/log/kubeadm-init.log"
      exit 1
  fi
fi

# Configure kubectl for regular user
echo "Step 12: Configuring kubectl for user $(whoami)..."
rm -rf $HOME/.kube || true
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Pod Network (Calico)
echo "Step 13: Deploying Calico network..."
kubectl apply -f https://docs.projectcalico.org/v3.25/manifests/calico.yaml

echo "Setup Complete. Kubernetes Master Node is ready!"
echo "Run the following command on worker nodes to join the cluster:"
kubeadm token create --print-join-command