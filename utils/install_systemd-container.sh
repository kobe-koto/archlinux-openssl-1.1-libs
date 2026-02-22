#!/bin/bash
echo "Installing systemd-container..."
if command -v apt &> /dev/null; then 
    sudo apt install -y systemd-container
elif command -v dnf &> /dev/null; then 
    sudo dnf install -y systemd-container
elif command -v zypper &> /dev/null; then
    sudo zypper -n install systemd-container
else
    echo "ERROR: could not install systemd-container, exiting...."
    exit 1
fi
