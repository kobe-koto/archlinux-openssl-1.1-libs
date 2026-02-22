#!/bin/bash
echo "Installing distrobox..."
if command -v pacman &> /dev/null; then 
    sudo pacman -Sy --noconfirm distrobox
elif command -v apt &> /dev/null; then 
    sudo apt install -y distrobox
elif command -v apk &> /dev/null; then
    sudo apk add distrobox
elif command -v dnf &> /dev/null; then
    sudo dnf install -y distrobox
elif command -v brew &> /dev/null; then
    sudo brew install distrobox
elif command -v zypper &> /dev/null; then
    sudo zypper -n install distrobox
else
    echo "ERROR: could not install distrobox, exiting...."
    exit 1
fi
