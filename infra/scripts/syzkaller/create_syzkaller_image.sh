#!/bin/bash

# Create Syzkaller-compatible Debian Trixie disk image
#
# Wraps Syzkaller's create-image.sh to produce a minimal Debian image
# suitable for Syzkaller fuzzing. Follows the official setup:
# https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md
#
# Output: $IMAGE_DIR/trixie.img, $IMAGE_DIR/trixie.id_rsa

set -e

BASE_DIR="${BASE_DIR:-/mnt/dev_ext_4tb}"
SRC_DIR="$BASE_DIR/open/src/syzkaller"
IMAGE_DIR="$BASE_DIR/open/vm/syzkaller"

mkdir -p "$IMAGE_DIR"
cd "$IMAGE_DIR"

if [ ! -f "$SRC_DIR/tools/create-image.sh" ]; then
    echo "ERROR: Syzkaller create-image.sh not found at $SRC_DIR/tools/create-image.sh"
    echo "Run setup_syzkaller.sh first to clone and build Syzkaller."
    exit 1
fi

echo "=== Creating Syzkaller Debian Trixie image ==="
echo "Output: $IMAGE_DIR/trixie.img"
echo "SSH key: $IMAGE_DIR/trixie.id_rsa"
echo

# Use Syzkaller's create-image.sh (minimal feature set by default)
"$SRC_DIR/tools/create-image.sh"

echo "Image created: $IMAGE_DIR/trixie.img"
echo "SSH key: $IMAGE_DIR/trixie.id_rsa"
echo "SSH: ssh -i $IMAGE_DIR/trixie.id_rsa -p PORT -o StrictHostKeyChecking=no root@localhost"
