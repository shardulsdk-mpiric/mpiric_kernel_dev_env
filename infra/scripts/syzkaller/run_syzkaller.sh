#!/bin/bash

# Syzkaller Manager Runner
#
# Starts syzkaller manager with config for Debian Trixie image.
# Prerequisites: setup_syzkaller.sh, create_syzkaller_image.sh, build_syzkaller_kernel.sh.

set -e

BASE_DIR="/mnt/dev_ext_4tb"
SYZKALLER_BUILD="$BASE_DIR/open/build/syzkaller"
KERNEL_BUILD="$BASE_DIR/open/build/linux/syzkaller"
IMAGE_DIR="$BASE_DIR/open/vm/syzkaller"
SHARED_DIR="$BASE_DIR/shared/syzkaller"
SCRIPTS_DIR="$BASE_DIR/infra/scripts/syzkaller"

echo "=== Starting Syzkaller ==="
echo "Manager: $SYZKALLER_BUILD/bin/syz-manager"
echo "Kernel:  $KERNEL_BUILD/arch/x86/boot/bzImage"
echo "Image:   $IMAGE_DIR/trixie.img"
echo

if [ ! -f "$SYZKALLER_BUILD/bin/syz-manager" ]; then
    echo "ERROR: syz-manager not found. Run setup_syzkaller.sh first."
    exit 1
fi

if [ ! -f "$KERNEL_BUILD/arch/x86/boot/bzImage" ]; then
    echo "ERROR: Kernel not found. Run build_syzkaller_kernel.sh first."
    exit 1
fi

if [ ! -f "$IMAGE_DIR/trixie.img" ]; then
    echo "ERROR: Debian image not found. Run create_syzkaller_image.sh first."
    exit 1
fi

mkdir -p "$SHARED_DIR/workdir"
cd "$SHARED_DIR"
"$SYZKALLER_BUILD/bin/syz-manager" -config "$SCRIPTS_DIR/syzkaller_manager.cfg"

echo "Syzkaller manager stopped."
