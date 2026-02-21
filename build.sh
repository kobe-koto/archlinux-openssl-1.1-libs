#!/bin/bash

CONTAINER_NAME="archlinux-build"
WORKER_USERNAME="worker"
DIST_FOLDER="$PWD/dist"

mkdir -p $DIST_FOLDER

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

if [[ " $@ " =~ " --distrobox " ]] && [[ " $@ " =~ " --nspawn " ]]; then
    echo "ERROR: --distrobox and --nspawn can't be used together"
    exit 1
elif [[ " $@ " =~ " --distrobox " ]]; then
    EXEC_PREFIX="distrobox enter $CONTAINER_NAME -- sudo"
    WORKER_EXEC_PREFIX="$EXEC_PREFIX runuser -u $WORKER_USERNAME --"

    echo ">>> Using distrobox to build"
    echo ">>> Creating container 'archlinux-build' using image 'archlinux:multilib-devel'..."

    # install distrobox if needed
    if ! command -v distrobox &> /dev/null; then 
        echo "Installing distrobox"
        echo "Installing distrobox requires root"
        keep_sudo_alive
        if command -v apt &> /dev/null; then 
            apt install -y distrobox
        elif command -v apk &> /dev/null; then
            apk add distrobox
        elif command -v yum &> /dev/null; then
            yum install -y distrobox
        elif command -v brew &> /dev/null; then
            brew install distrobox
        elif command -v zypper &> /dev/null; then
            zypper -n install distrobox
        else
            echo "ERROR: could not install distrobox, exiting...."
            exit 1
        fi
    fi

    # set up a archlinux container using distrobox
    distrobox create -Y --name $CONTAINER_NAME --image archlinux:multilib-devel --volume $DIST_FOLDER:/root/dist_bridge
    $EXEC_PREFIX pacman -Syu --noconfirm
    $EXEC_PREFIX pacman -S --noconfirm git

elif [[ " $@ " =~ " --nspawn " ]]; then
    EXEC_PREFIX="sudo systemd-nspawn -qD ./$CONTAINER_NAME/ --bind $DIST_FOLDER:/root/dist_bridge --"
    WORKER_EXEC_PREFIX="$EXEC_PREFIX runuser -u $WORKER_USERNAME --"
    echo ">>> Using systemd-nspawn to build (Arch Only)"
    echo "Using systemd-nspawn requires root."
    keep_sudo_alive
    if ! command -v pacstrap &> /dev/null; then 
        echo "installing package 'arch-install-scripts'..."
        sudo pacman -Sy arch-install-scripts --noconfirm
    fi
    if [ ! -d "$CONTAINER_NAME" ]; then
        echo "Creating container $CONTAINER_NAME..."
        mkdir -p $CONTAINER_NAME
        sudo pacstrap -K -c ./$CONTAINER_NAME base base-devel multilib-devel git
        $EXEC_PREFIX pacman-key --init
        $EXEC_PREFIX pacman-key --populate
    fi
else 
    echo "ERROR: --nspawn or --distrobox must be specified"
    exit 1
fi

# ==== PREPARE ====
# config: make using nproc-1 cores
ExpectedMakeFlags="MAKEFLAGS='-j$(($(nproc)-1))'"
if ! $EXEC_PREFIX bash -c "grep -qxF $ExpectedMakeFlags /etc/makepkg.conf"; then
    echo "Setting MAKEFLAGES to $ExpectedMakeFlags..."
    $EXEC_PREFIX bash -c "echo $ExpectedMakeFlags >> /etc/makepkg.conf"
fi

# chore: create a worker user
if ! $EXEC_PREFIX id "$WORKER_USERNAME" &>/dev/null; then
    echo "Creating user $WORKER_USERNAME..."
    $EXEC_PREFIX useradd -m -s /bin/bash $WORKER_USERNAME
    $EXEC_PREFIX usermod -aG wheel,audio,video,optical,storage $WORKER_USERNAME
    $EXEC_PREFIX bash -c "echo \"$WORKER_USERNAME ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers"
fi

# ==== BUILD ====
# chore: make working folder
$EXEC_PREFIX mkdir -p /var/cache/build/
$EXEC_PREFIX chmod 777 /var/cache/build/

# build: openssl-1.1
$WORKER_EXEC_PREFIX git clone https://aur.archlinux.org/openssl-1.1.git /var/cache/build/openssl-1.1
$WORKER_EXEC_PREFIX bash -c "gpg --import /var/cache/build/openssl-1.1/keys/pgp/*"
$WORKER_EXEC_PREFIX makepkg -D /var/cache/build/openssl-1.1 -Ccsi --noconfirm

# build: lib32-openssl-1.1
$WORKER_EXEC_PREFIX git clone https://aur.archlinux.org/lib32-openssl-1.1.git /var/cache/build/lib32-openssl-1.1
$WORKER_EXEC_PREFIX makepkg -D /var/cache/build/lib32-openssl-1.1 -Ccsi --noconfirm

# ==== REPO ====
$EXEC_PREFIX mkdir -p /var/cache/openssl-1.1-libs/x86_64/
$EXEC_PREFIX cp /var/cache/build/openssl-1.1/openssl-1.1-*.pkg.tar.zst /var/cache/openssl-1.1-libs/x86_64/
$EXEC_PREFIX cp /var/cache/build/lib32-openssl-1.1/lib32-openssl-1.1-*.pkg.tar.zst /var/cache/openssl-1.1-libs/x86_64/
$EXEC_PREFIX repo-add /var/cache/openssl-1.1-libs/x86_64/openssl-1.1-libs.db.tar.gz /var/cache/openssl-1.1-libs/x86_64/*.pkg.tar.zst

# ==== TARBALL ====
$EXEC_PREFIX tar -cf /root/dist_bridge/openssl-1.1-libs.tar /var/cache/openssl-1.1-libs/x86_64/

# ==== CLEAN UP ====
$EXEC_PREFIX rm -rf /var/cache/build/

# ==== RELEASE ====
rm x86_64/ -rf
tar --no-same-permissions --no-same-owner --strip-components=3 -xvf $DIST_FOLDER/openssl-1.1-libs.tar
