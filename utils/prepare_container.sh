#!/bin/bash
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
    $EXEC_PREFIX useradd -m -s /bin/bash "$WORKER_USERNAME"
    $EXEC_PREFIX usermod -aG wheel,audio,video,optical,storage "$WORKER_USERNAME"
    $EXEC_PREFIX bash -c "echo \"$WORKER_USERNAME ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers"
fi
