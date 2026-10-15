#!/bin/bash
CREATE_OPTIONS=()
TMPFS_FLAGS=()
if [[ -n "${TMP_SIZE:-}" ]]; then
    TMPFS_FLAGS+=(--tmpfs "/var/tmp/aur-builder:rw,exec,size=$TMP_SIZE,mode=1777")
fi
if [[ -n "${BUILD_TMP_SIZE:-}" ]]; then
    TMPFS_FLAGS+=(--tmpfs "/build:rw,exec,size=$BUILD_TMP_SIZE,mode=1777")
fi
if [[ ${#TMPFS_FLAGS[@]} -gt 0 ]]; then
    CREATE_OPTIONS+=(--additional-flags "${TMPFS_FLAGS[*]}")
fi
distrobox create -Y --name "$CONTAINER_NAME" --image archlinux:multilib-devel --volume "$DIST_FOLDER:/root/dist_bridge" --volume "$PWD/utils/container/build.sh:/usr/local/bin/container_build.sh" "${CREATE_OPTIONS[@]}" || exit 1
$EXEC_PREFIX pacman -Syu --noconfirm
$EXEC_PREFIX pacman -S --noconfirm git
# prepare
EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME bash utils/prepare_container.sh
