#!/bin/bash

WORKER_EXEC_PREFIX="runuser -u ${1:-worker} --"

WORKING_FOLDER="/var/cache"
BUILD_FOLDER="$BUILD_FOLDER/build"
REPO_FOLDER="$WORKING_FOLDER/openssl-1.1-libs"

# ==== BUILD ====
# chore: make working folder
mkdir -p "$BUILD_FOLDER"
chmod 777 "$BUILD_FOLDER"

# build: openssl-1.1
$WORKER_EXEC_PREFIX git clone https://aur.archlinux.org/openssl-1.1.git "$BUILD_FOLDER/openssl-1.1"
$WORKER_EXEC_PREFIX gpg --import "$BUILD_FOLDER"/openssl-1.1/keys/pgp/*
$WORKER_EXEC_PREFIX makepkg -D "$BUILD_FOLDER/openssl-1.1" -Ccsi --noconfirm

# build: lib32-openssl-1.1
$WORKER_EXEC_PREFIX git clone https://aur.archlinux.org/lib32-openssl-1.1.git "$BUILD_FOLDER/lib32-openssl-1.1"
$WORKER_EXEC_PREFIX makepkg -D "$BUILD_FOLDER/lib32-openssl-1.1" -Ccsi --noconfirm

# ==== REPO ====
mkdir -p "$REPO_FOLDER/x86_64/"
cp "$BUILD_FOLDER"/openssl-1.1/openssl-1.1-*.pkg.tar.zst "$REPO_FOLDER/x86_64/"
cp "$BUILD_FOLDER"/lib32-openssl-1.1/lib32-openssl-1.1-*.pkg.tar.zst "$REPO_FOLDER/x86_64/"
repo-add "$REPO_FOLDER/x86_64/openssl-1.1-libs.db.tar.gz" "$REPO_FOLDER"/x86_64/*.pkg.tar.zst

# ==== TIMESTAMP ====
date +%s > "$REPO_FOLDER/x86_64/lastupdate"
cp -f "$REPO_FOLDER/x86_64/lastupdate" "$REPO_FOLDER/x86_64/lastsync"

# ==== TARBALL ====
tar -cf /root/dist_bridge/openssl-1.1-libs.tar "$REPO_FOLDER/x86_64/"

# ==== CLEAN UP ====
rm -rf "$BUILD_FOLDER"
rm -rf "$REPO_FOLDER"
