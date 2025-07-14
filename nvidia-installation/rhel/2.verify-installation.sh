#!/bin/bash

# Step 11: Install nvitop for monitoring
sudo dnf install -y pip
pip install nvitop

# Step 12: Verify NVIDIA installation
echo "Verifying NVIDIA installation..."
nvidia-smi

echo "Setup completed for nvidia driver installation"

