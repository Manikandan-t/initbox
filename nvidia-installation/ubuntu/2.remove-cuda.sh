#!/bin/bash

# remove cuda

sudo apt-get -y remove --purge '^cuda.*'
sudo apt-get -y remove --purge '^cuda*'
sudo dpkg -P "$(dpkg -l | grep cuda | awk '{print $2}')"
sudo apt -y autoremove


echo "system will restart "
read -r -p "want to proceed : (yes/no)" n

case $n in

	yes)sudo reboot;;
	no) exit 0 ;;
     *)sudo reboot;;


esac