#!/bin/bash
sudo pacstrap -K -c "$CONTAINER_NAME/" base base-devel multilib-devel git
# populate and initialize keys
$EXEC_PREFIX pacman-key --init
$EXEC_PREFIX pacman-key --populate
# prepare
EXEC_PREFIX=$EXEC_PREFIX WORKER_USERNAME=$WORKER_USERNAME bash utils/prepare_container.sh
