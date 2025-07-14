#!/bin/bash

# Uninstall previous NVIDIA drivers and CUDA
sudo apt-get -y remove --purge '^nvidia-.*'
sudo dpkg -P "$(dpkg -l | grep nvidia | awk '{print $2}')"
sudo apt -y autoremove

echo "system will restart "
read -r -p "want to proceed : (yes/no)" n

case $n in

	yes)sudo reboot;;
	no) exit 0 ;;
     *)sudo reboot;;


esac