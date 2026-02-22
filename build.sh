#!/bin/bash

MODE=""
NSPAWN_METHOD=""
CONTAINER_NAME="archlinux-build"
WORKER_USERNAME="worker"
DIST_FOLDER="$PWD/dist"

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
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [ --distrobox | --nspawn=[pacstrap|bootstrap] ]"
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "ERROR: Mode must be specified."
    exit 1
fi

echo ">>> Mode: $MODE (Method: ${NSPAWN_METHOD:-N/A})"

echo ">>> Checking AUR for updates..."
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required to check AUR versions. Please install it."
    exit 1
fi

AUR_INFO=$(curl -s "https://aur.archlinux.org/rpc/v5/info?arg[]=openssl-1.1&arg[]=lib32-openssl-1.1")
AUR_VER_OPENSSL=$(echo "$AUR_INFO" | jq -r '.results[] | select(.Name == "openssl-1.1") | .Version // empty')
AUR_VER_LIB32=$(echo "$AUR_INFO" | jq -r '.results[] | select(.Name == "lib32-openssl-1.1") | .Version // empty')

if [[ -z "$AUR_VER_OPENSSL" || -z "$AUR_VER_LIB32" ]]; then
    echo "ERROR: Failed to fetch versions from AUR."
    exit 1
fi

if [[ -f "x86_64/openssl-1.1-${AUR_VER_OPENSSL}-x86_64.pkg.tar.zst" && -f "x86_64/lib32-openssl-1.1-${AUR_VER_LIB32}-x86_64.pkg.tar.zst" ]]; then
    echo ">>> Versions are up-to-date (openssl-1.1: $AUR_VER_OPENSSL, lib32-openssl-1.1: $AUR_VER_LIB32)."
    echo ">>> No build needed."
    exit 0
fi

echo ">>> Version mismatch or packages missing. Proceeding with build..."

if [[ "$MODE" == "distrobox" ]]; then
    EXEC_PREFIX="distrobox enter $CONTAINER_NAME -- sudo"

    # Check distrobox installation
    if ! command -v distrobox &> /dev/null; then 
        bash utils/install_distrobox.sh
    fi

    CONTAINER_NAME=$CONTAINER_NAME EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME DIST_FOLDER=$DIST_FOLDER bash utils/build_box_distrobox.sh
elif [[ "$MODE" == "nspawn" ]]; then
    EXEC_PREFIX="sudo systemd-nspawn -qD ./$CONTAINER_NAME/ --bind $DIST_FOLDER:/root/dist_bridge --bind $PWD/utils/container/build.sh:/usr/local/bin/container_build.sh --"

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

# ==== UPDATE ====
$EXEC_PREFIX sudo pacman -Syu --disable-sandbox --noconfirm

# ==== BUILD ====
$EXEC_PREFIX sudo bash container_build.sh $WORKER_USERNAME

# ==== RELEASE ====
rm x86_64/ -rf
tar --no-same-permissions --no-same-owner --strip-components=3 -xvf "$DIST_FOLDER/openssl-1.1-libs.tar"
