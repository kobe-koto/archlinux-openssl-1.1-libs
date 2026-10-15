#!/bin/bash

set -e

CUSTOM_REPO="${CUSTOM_REPO:-openssl-1.1-libs}"
ENABLE_MOLD="${ENABLE_MOLD:-0}"
if [[ ! "$CUSTOM_REPO" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    echo "ERROR: Invalid repository name '$CUSTOM_REPO'." >&2
    exit 1
fi

if [[ "$ENABLE_MOLD" != 0 && "$ENABLE_MOLD" != 1 ]]; then
    echo "ERROR: ENABLE_MOLD must be 0 or 1." >&2
    exit 1
fi

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 worker-username aur-package [aur-package ...]" >&2
    exit 1
fi

WORKER_EXEC_PREFIX=(runuser -u "$1" --)
shift
AUR_PACKAGES=("$@")

WORKING_FOLDER="/var/cache"
BUILD_FOLDER="$BUILD_FOLDER/build"
REPO_FOLDER="$WORKING_FOLDER/repo/$CUSTOM_REPO"

# ==== BUILD ====
LINKER_PREFIX=()
if [[ "$ENABLE_MOLD" == 1 ]]; then
    if ! command -v mold > /dev/null; then
        pacman -S --needed --disable-sandbox --noconfirm mold
    fi
    LINKER_PREFIX=(mold -run)
    echo ">>> Using mold -run for package builds."
fi

# chore: make working folder
mkdir -p "$BUILD_FOLDER"
chmod 777 "$BUILD_FOLDER"

for package in "${AUR_PACKAGES[@]}"; do
    package_dir="$BUILD_FOLDER/$package"
    "${WORKER_EXEC_PREFIX[@]}" git clone "https://aur.archlinux.org/$package.git" "$package_dir"
    for key in "$package_dir"/keys/pgp/*; do
        [[ -f "$key" ]] || continue
        "${WORKER_EXEC_PREFIX[@]}" gpg --import "$key"
    done
    "${WORKER_EXEC_PREFIX[@]}" "${LINKER_PREFIX[@]}" makepkg -D "$package_dir" -Ccsi --noconfirm
done

# ==== REPO ====
mkdir -p "$REPO_FOLDER"
for package in "${AUR_PACKAGES[@]}"; do
    cp "$BUILD_FOLDER/$package"/*.pkg.tar.zst "$REPO_FOLDER/"
done
repo-add "$REPO_FOLDER/$CUSTOM_REPO.db.tar.gz" "$REPO_FOLDER"/*.pkg.tar.zst

# ==== TIMESTAMP ====
date +%s > "$REPO_FOLDER/lastupdate"
cp -f "$REPO_FOLDER/lastupdate" "$REPO_FOLDER/lastsync"

# ==== TARBALL ====
tar -cf "/root/dist_bridge/$CUSTOM_REPO.tar" -C "$REPO_FOLDER" .

# ==== CLEAN UP ====
rm -rf "$BUILD_FOLDER"
rm -rf "$REPO_FOLDER"
