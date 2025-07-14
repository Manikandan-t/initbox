#!/bin/bash

set -e

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y build-essential dkms curl

# Add NVIDIA CUDA APT repository
echo "Adding NVIDIA APT repository..."
CUDA_REPO_PKG="cuda-keyring_1.1-1_all.deb"
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/${CUDA_REPO_PKG}
sudo dpkg -i ${CUDA_REPO_PKG}
sudo apt update

# Install the latest driver and toolkit
echo "Installing latest NVIDIA driver and CUDA toolkit..."
sudo apt install -y cuda

# Optionally install specific version:
# sudo apt install -y cuda-12-3  (replace with desired version)

echo "CUDA installation complete."

# Set environment variables
echo "Configuring environment variables..."
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

# Apply changes
source ~/.bashrc

# Prompt for reboot
read -r -p "Reboot now to enable NVIDIA driver? (yes/no): " answer
if [[ $answer =~ ^(yes|y)$ ]]; then
    sudo reboot
else
    echo "Please reboot manually to finish the installation."
fi