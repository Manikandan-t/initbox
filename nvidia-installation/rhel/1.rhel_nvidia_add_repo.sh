#!/bin/bash

# Function to check the reboot confirmation
confirm_reboot() {
    read -r -p "Reboot is required to apply changes. Do you want to reboot now? (y/n): " response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Rebooting now..."
            sudo reboot
            ;;
        *)
            echo "Reboot skipped. Please reboot manually later."
            ;;
    esac
}

# Step 1: Add NVIDIA repository
echo "Adding NVIDIA official repository..."
dnf config-manager --add-repo http://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo

# Step 2: Confirm the GPU card on the computer
echo "Detecting GPU card..."
lspci | grep VGA

# Step 3: Display available NVIDIA driver versions
echo "Listing available NVIDIA driver versions..."
dnf module list nvidia-driver

# Clean up files if exists
sudo dnf autoremove -y nvidia*

# Step 4: Install the latest NVIDIA driver
echo "Installing the latest NVIDIA driver..."
sudo dnf module reset -y nvidia-driver

#For specific version
sudo dnf module -y install nvidia-driver:565-dkms

#For latest version
sudo dnf module -y install nvidia-driver:latest-dkms

# Step 5: Load the NVIDIA driver
echo "Loading NVIDIA driver..."
sudo nvidia-modprobe && nvidia-modprobe -u

# Step 6: Check if 'nouveau' driver is loaded and prompt for reboot
if lsmod | grep -q nouveau; then
    echo "Detected 'nouveau' driver. A reboot is required to load the NVIDIA driver."
    confirm_reboot
else
    echo "NVIDIA driver loaded successfully. No reboot required."
fi