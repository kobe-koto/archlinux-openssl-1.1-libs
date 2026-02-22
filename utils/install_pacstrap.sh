#!/bin/bash
echo "Installing pacstrap/arch-install-scripts..."
if command -v pacman &> /dev/null; then 
    sudo pacman -Sy --noconfirm arch-install-scripts
    # if command -v apt &> /dev/null; then
    #     sudo apt install -y arch-install-scripts
    # elif command -v apk &> /dev/null; then
    #     sudo apk add arch-install-scripts
    # elif command -v dnf &> /dev/null; then
    #     sudo dnf install -y arch-install-scripts
    # elif command -v zypper &> /dev/null; then
    #     sudo zypper -n install arch-install-scripts
    # else
    #     echo "ERROR: could not install arch-install-scripts, exiting...."
    #     exit 1
    # fi
else 
    echo "ERROR: Please install pacman and arch-install-scripts, and then enable `core`, `extra`, `multilib` repositories manually."
    exit 1;
fi
