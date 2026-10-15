#!/bin/bash

set -e

CUSTOM_REPO="${CUSTOM_REPO:-openssl-1.1-libs}"
ENABLE_MOLD="${ENABLE_MOLD:-0}"
export ENABLE_LLVM="${ENABLE_LLVM:-0}"
if [[ ! "$CUSTOM_REPO" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    echo "ERROR: Invalid repository name '$CUSTOM_REPO'." >&2
    exit 1
fi

if [[ "$ENABLE_MOLD" != 0 && "$ENABLE_MOLD" != 1 ]]; then
    echo "ERROR: ENABLE_MOLD must be 0 or 1." >&2
    exit 1
fi

if [[ "$ENABLE_LLVM" != 0 && "$ENABLE_LLVM" != 1 ]]; then
    echo "ERROR: ENABLE_LLVM must be 0 or 1." >&2
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
MAKEPKG_OPTIONS=()
if [[ "$ENABLE_LLVM" == 1 ]]; then
    for tool in clang clang++ llvm-ar llvm-ranlib llvm-nm ld.lld; do
        if ! command -v "$tool" > /dev/null; then
            pacman -S --needed --disable-sandbox --noconfirm clang llvm lld
            break
        fi
    done

    MAKEPKG_CONFIG=$(mktemp "${TMPDIR:-/tmp}/aur-makepkg.XXXXXX.conf")
    trap 'rm -f -- "$MAKEPKG_CONFIG"' EXIT
    cat > "$MAKEPKG_CONFIG" <<'CONFIG'
# Load the standard system, drop-in, and worker-user configuration first.
source /usr/share/makepkg/util/config.sh
source_makepkg_config /etc/makepkg.conf

export CC=clang CXX=clang++
export AR=llvm-ar RANLIB=llvm-ranlib NM=llvm-nm
# Clang does not support GCC's -flto=auto spelling.
LTOFLAGS="${LTOFLAGS//-flto=auto/-flto=full}"
if [[ "${ENABLE_MOLD:-0}" != 1 ]]; then
    export LD=ld.lld
    LDFLAGS+=" -fuse-ld=lld"
fi
CONFIG
    chmod 644 "$MAKEPKG_CONFIG"
    MAKEPKG_OPTIONS=(--config "$MAKEPKG_CONFIG")
    echo ">>> Using the Clang/LLVM toolchain."
fi

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
    "${WORKER_EXEC_PREFIX[@]}" "${LINKER_PREFIX[@]}" makepkg "${MAKEPKG_OPTIONS[@]}" -D "$package_dir" -Ccsi --noconfirm
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
