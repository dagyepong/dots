#!/bin/bash
#  ____           _                 _  
# |  _ \ _ __ ___| | ___   __ _  __| | 
# | |_) | '__/ _ \ |/ _ \ / _` |/ _` | 
# |  __/| | |  __/ | (_) | (_| | (_| | 
# |_|   |_|  \___|_|\___/ \__,_|\__,_| 
#                                      
# by Stephan Raabe (2023) 
# ----------------------------------------------------- 
# Preload Install Script
# yay must be installed
# -----------------------------------------------------
# NAME: Preload Installation
# DESC: Installation script for preload
# WARNING: Run this script at your own risk.

clear
echo " ____           _                 _  "
echo "|  _ \ _ __ ___| | ___   __ _  __| | "
echo "| |_) | '__/ _ \ |/ _ \ / _' |/ _' | "
echo "|  __/| | |  __/ | (_) | (_| | (_| | "
echo "|_|   |_|  \___|_|\___/ \__,_|\__,_| "
echo "                                      "
echo ""

# -----------------------------------------------------
# Confirm Start
# -----------------------------------------------------
while true; do
    read -p "DO YOU WANT TO START THE INSTALLATION NOW? (Yy/Nn): " yn
    case $yn in
        [Yy]* )
            echo "Installation started."
        break;;
        [Nn]* ) 
            exit;
        break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# -----------------------------------------------------
# Install zram
# -----------------------------------------------------
yay --noconfirm -S preload

echo "DONE!"
