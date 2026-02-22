#!/bin/bash
echo "Installing curl and jq..."
if command -v pacman &> /dev/null; then 
    sudo pacman -Sy --noconfirm curl jq
elif command -v apt &> /dev/null; then 
    sudo apt install -y curl jq
elif command -v apk &> /dev/null; then
    sudo apk add curl jq
elif command -v dnf &> /dev/null; then
    sudo dnf install -y curl jq
elif command -v brew &> /dev/null; then
    sudo brew install curl jq
elif command -v zypper &> /dev/null; then
    sudo zypper -n install curl jq
else
    echo "ERROR: could not install curl and jq, exiting...."
    exit 1
fi
