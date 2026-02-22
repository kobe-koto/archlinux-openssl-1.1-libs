#!/bin/bash
# Download latest bootstrap tarball
curl -L https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst -o ./tmp/archlinux-bootstrap-x86_64.tar.zst
sudo tar --one-top-level="$CONTAINER_NAME/" --strip-components=1 -xf ./tmp/archlinux-bootstrap-x86_64.tar.zst
        
# populate and initialize keys
$EXEC_PREFIX pacman-key --init
$EXEC_PREFIX pacman-key --populate

# configure pacman 
$EXEC_PREFIX bash -c "echo Server = https://geo.mirror.pkgbuild.com/\\\$repo/os/\\\$arch >> /etc/pacman.d/mirrorlist"
$EXEC_PREFIX bash -c "echo [multilib] >> /etc/pacman.conf"
$EXEC_PREFIX bash -c "echo Include = /etc/pacman.d/mirrorlist >> /etc/pacman.conf"

# Install required packages
$EXEC_PREFIX pacman -Syu --disable-sandbox --noconfirm
$EXEC_PREFIX pacman -S --disable-sandbox --noconfirm base-devel multilib-devel git

# prepare
EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME bash utils/prepare_container.sh
