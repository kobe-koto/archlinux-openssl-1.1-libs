#!/bin/bash

MODE=""
NSPAWN_METHOD=""
CONTAINER_NAME="archlinux-build"
WORKER_USERNAME="worker"
DIST_FOLDER="$PWD/dist"
CUSTOM_REPO="${CUSTOM_REPO:-openssl-1.1-libs}"
TMP_SIZE="${TMP_SIZE:-}"
BUILD_TMP_SIZE="${BUILD_TMP_SIZE:-}"
DEFAULT_AUR_PACKAGES=("openssl-1.1" "lib32-openssl-1.1")
AUR_PACKAGES=()

if [[ ! "$CUSTOM_REPO" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    echo "ERROR: Invalid repository name '$CUSTOM_REPO'." >&2
    exit 1
fi

for size in "$TMP_SIZE" "$BUILD_TMP_SIZE"; do
    if [[ -n "$size" && ! "$size" =~ ^[1-9][0-9]*[kKmMgGtT]?$ ]]; then
        echo "ERROR: Invalid tmpfs size '$size'. Use a positive byte count or K/M/G/T suffix." >&2
        exit 1
    fi
done

REPO_FOLDER="$PWD/repo/$CUSTOM_REPO"

mkdir -p "$DIST_FOLDER"
mkdir -p tmp/

keep_sudo_alive() {
    # Update the sudo timestamp immediately
    sudo -v

    # Periodically update the timestamp in the background
    while true; do
        # 'sudo -n' runs in non-interactive mode (no password prompt)
        sudo -n true
        sleep 60
    
        # Check if the parent script is still running
        # If not ($$ is the script's PID), kill this background loop
        kill -0 "$$" || exit
    done 2>/dev/null &
}

# check for dependencies
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    sudo bash utils/install_curl_jq.sh
fi

# Improved Argument Parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        --distrobox)
            if [[ -n "$MODE" ]]; then echo "ERROR: Conflicting modes."; exit 1; fi
            MODE="distrobox"
            shift
            ;;
        --nspawn=*)
            if [[ -n "$MODE" ]]; then echo "ERROR: Conflicting modes."; exit 1; fi
            MODE="nspawn"
            # Extract value after the '='
            NSPAWN_METHOD="${1#*=}" 
            if [[ "$NSPAWN_METHOD" != "pacstrap" && "$NSPAWN_METHOD" != "bootstrap" ]]; then
                echo "ERROR: Invalid nspawn method '$NSPAWN_METHOD'. Use 'pacstrap' or 'bootstrap'."
                exit 1
            fi
            shift
            ;;
        --nspawn) # Handle case where user doesn't provide =value
            if [[ -n "$MODE" ]]; then echo "ERROR: Conflicting modes."; exit 1; fi
            echo "WARNING: No nspawn method provided, fallback to 'pacstrap'"
            MODE="nspawn"
            NSPAWN_METHOD="pacstrap"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [ --distrobox | --nspawn=[pacstrap|bootstrap] ] [aur-package ...]"
            exit 1
            ;;
        *)
            AUR_PACKAGES+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "ERROR: Mode must be specified."
    exit 1
fi

if [[ ${#AUR_PACKAGES[@]} -eq 0 ]]; then
    AUR_PACKAGES=("${DEFAULT_AUR_PACKAGES[@]}")
fi

echo ">>> Mode: $MODE (Method: ${NSPAWN_METHOD:-N/A})"
echo ">>> Repository: $CUSTOM_REPO"
echo ">>> AUR packages: ${AUR_PACKAGES[*]}"

if [[ "$MODE" == "distrobox" ]]; then
    EXEC_PREFIX="distrobox enter $CONTAINER_NAME -- sudo"

    # Check distrobox installation
    if ! command -v distrobox &> /dev/null; then 
        bash utils/install_distrobox.sh
    fi

    CONTAINER_NAME=$CONTAINER_NAME EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME DIST_FOLDER=$DIST_FOLDER TMP_SIZE=$TMP_SIZE BUILD_TMP_SIZE=$BUILD_TMP_SIZE bash utils/build_box_distrobox.sh || exit 1
elif [[ "$MODE" == "nspawn" ]]; then
    TMPFS_OPTIONS=()
    if [[ -n "$TMP_SIZE" ]]; then
        TMPFS_OPTIONS+=("--tmpfs=/var/tmp/aur-builder:size=$TMP_SIZE,mode=1777,exec")
    fi
    if [[ -n "$BUILD_TMP_SIZE" ]]; then
        TMPFS_OPTIONS+=("--tmpfs=/build:size=$BUILD_TMP_SIZE,mode=1777,exec")
    fi
    EXEC_PREFIX="sudo systemd-nspawn -qD ./$CONTAINER_NAME/ --bind $DIST_FOLDER:/root/dist_bridge --bind $PWD/utils/container/build.sh:/usr/local/bin/container_build.sh ${TMPFS_OPTIONS[*]} --"

    echo "INFO: systemd-nspawn requires root"
    keep_sudo_alive

    if ! command -v systemd-nspawn; then
        bash utils/install_systemd-container.sh
    fi

    if [ -d "$CONTAINER_NAME" ]; then
        echo "INFO: Container $CONTAINER_NAME exists, skipping build container..."
    else
        mkdir -p $CONTAINER_NAME
        if [[ "$NSPAWN_METHOD" == "pacstrap" ]]; then
            # Check pacstrap presence
            if ! command -v pacstrap; then
                bash utils/install_pacstrap.sh
            fi
            CONTAINER_NAME=$CONTAINER_NAME EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME bash utils/build_chroot_pacstrap.sh
        elif [[ "$NSPAWN_METHOD" == "bootstrap" ]]; then
            CONTAINER_NAME=$CONTAINER_NAME EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME bash utils/build_chroot_bootstrap.sh
        fi
    fi
else
    echo "ERROR: No vaild MODE to proceed, how could this happen?"
    exit 1;
fi

# ==== UPDATE CONTAINER ====
$EXEC_PREFIX sudo pacman -Syu --disable-sandbox --noconfirm

# ==== CHECK AUR FOR UPDATES ====
echo ">>> Checking AUR for updates..."
AUR_QUERY_ARGS=()
for package in "${AUR_PACKAGES[@]}"; do
    AUR_QUERY_ARGS+=(--data-urlencode "arg[]=$package")
done

if ! AUR_INFO=$(curl --fail --silent --show-error --get "${AUR_QUERY_ARGS[@]}" "https://aur.archlinux.org/rpc/v5/info"); then
    echo "ERROR: Failed to fetch versions from AUR."
    exit 1
fi

ALL_UP_TO_DATE=true
if [[ ! -f "$REPO_FOLDER/$CUSTOM_REPO.db.tar.gz" || ! -f "$REPO_FOLDER/$CUSTOM_REPO.files.tar.gz" ]]; then
    ALL_UP_TO_DATE=false
fi
for package in "${AUR_PACKAGES[@]}"; do
    if ! version=$(jq -er --arg package "$package" '.results[] | select(.Name == $package) | .Version | select(type == "string" and length > 0)' <<< "$AUR_INFO"); then
        echo "ERROR: Failed to fetch version from AUR for '$package'."
        exit 1
    fi
    echo ">>> $package: $version"
    package_files=("$REPO_FOLDER/${package}-${version}-"*.pkg.tar.zst)
    if [[ ! -f "${package_files[0]}" ]]; then
        ALL_UP_TO_DATE=false
    fi
done

if [[ "$ALL_UP_TO_DATE" == true ]]; then
    echo ">>> Versions are up-to-date."
    echo ">>> No build needed."
    exit 0
fi
echo ">>> Version mismatch or packages missing. Proceeding with build..."

# ==== BUILD ====
CONTAINER_ENV=("CUSTOM_REPO=$CUSTOM_REPO")
if [[ -n "$TMP_SIZE" ]]; then
    CONTAINER_ENV+=(TMPDIR=/var/tmp/aur-builder)
fi
if ! $EXEC_PREFIX sudo env "${CONTAINER_ENV[@]}" bash container_build.sh "$WORKER_USERNAME" "${AUR_PACKAGES[@]}"; then
    echo "ERROR: Container build failed." >&2
    exit 1
fi

# ==== RELEASE ====
if ! tar -tf "$DIST_FOLDER/$CUSTOM_REPO.tar" > /dev/null; then
    echo "ERROR: Repository archive is missing or invalid." >&2
    exit 1
fi
rm -rf -- "$REPO_FOLDER"
mkdir -p "$REPO_FOLDER" || exit 1
tar --no-same-permissions --no-same-owner -xvf "$DIST_FOLDER/$CUSTOM_REPO.tar" -C "$REPO_FOLDER"
