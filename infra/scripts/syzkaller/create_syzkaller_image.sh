#!/bin/bash

# Create Syzkaller-compatible Debian Trixie disk image
#
# Wraps Syzkaller's create-image.sh to produce a minimal Debian image
# suitable for Syzkaller fuzzing. Follows the official setup:
# https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md
#
# Also configures the image to auto-mount the 9p shared dir at /mnt/host
# when QEMU is started with -virtfs (see run_qemu_syzkaller.sh).
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

echo "Configuring auto-mount of 9p shared dir at /mnt/host..."
MOUNT_POINT="$(mktemp -d)"
cleanup() { sudo umount "$MOUNT_POINT" 2>/dev/null; rmdir "$MOUNT_POINT" 2>/dev/null; }
trap cleanup EXIT

sudo mount -o loop trixie.img "$MOUNT_POINT"
sudo mkdir -p "$MOUNT_POINT/mnt/host"
# Use fstab + x-systemd.automount to avoid 9p-at-boot race; mounts on first access to /mnt/host
echo 'hostshare /mnt/host 9p trans=virtio,version=9p2000.L,noauto,x-systemd.automount 0 0' | \
    sudo tee -a "$MOUNT_POINT/etc/fstab" > /dev/null
sudo umount "$MOUNT_POINT"
trap - EXIT
rmdir "$MOUNT_POINT"

echo "Image created: $IMAGE_DIR/trixie.img"
echo "SSH key: $IMAGE_DIR/trixie.id_rsa"
echo "Shared dir $BASE_DIR/shared → /mnt/host in guest (automount on first access)."
echo "SSH: ssh -i $IMAGE_DIR/trixie.id_rsa -p PORT -o StrictHostKeyChecking=no root@localhost"
