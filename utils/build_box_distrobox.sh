#!/bin/bash
distrobox create -Y --name "$CONTAINER_NAME" --image archlinux:multilib-devel --volume "$DIST_FOLDER:/root/dist_bridge" --volume "$PWD/utils/container/build.sh:/usr/local/bin/container_build.sh"
$EXEC_PREFIX pacman -Syu --noconfirm
$EXEC_PREFIX pacman -S --noconfirm git
# prepare
EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME bash utils/prepare_container.sh
