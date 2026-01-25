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

# Create swap file for syz-execprog/syz-executor (fixes "shmem mmap failed" errors)
# syz-executor needs swap support for certain syscalls (swapon, mkswap, etc.)
# See: https://github.com/google/syzkaller/issues/XXXX (common issue with minimal images)
echo "Creating swap file for Syzkaller executor..."
sudo dd if=/dev/zero of="$MOUNT_POINT/swapfile" bs=1M count=64 status=progress 2>/dev/null || \
    sudo dd if=/dev/zero of="$MOUNT_POINT/swapfile" bs=1M count=64
sudo chmod 600 "$MOUNT_POINT/swapfile"
# Add systemd service to format and enable swap at boot (swap file needs mkswap first)
sudo tee "$MOUNT_POINT/etc/systemd/system/setup-swap.service" > /dev/null << 'SWAPEOF'
[Unit]
Description=Setup swap file for Syzkaller
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'if ! swapon --show | grep -q swapfile; then mkswap /swapfile && swapon /swapfile; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SWAPEOF
sudo ln -sf /etc/systemd/system/setup-swap.service \
    "$MOUNT_POINT/etc/systemd/system/multi-user.target.wants/setup-swap.service" 2>/dev/null || \
    (sudo mkdir -p "$MOUNT_POINT/etc/systemd/system/multi-user.target.wants" && \
     sudo ln -sf /etc/systemd/system/setup-swap.service \
         "$MOUNT_POINT/etc/systemd/system/multi-user.target.wants/setup-swap.service")

sudo umount "$MOUNT_POINT"
trap - EXIT
rmdir "$MOUNT_POINT"

echo "Image created: $IMAGE_DIR/trixie.img"
echo "SSH key: $IMAGE_DIR/trixie.id_rsa"
echo "Shared dir $BASE_DIR/shared → /mnt/host in guest (automount on first access)."
echo "Swap file: 64MB /swapfile (auto-enabled at boot for syz-executor)."
echo "SSH: ssh -i $IMAGE_DIR/trixie.id_rsa -p PORT -o StrictHostKeyChecking=no root@localhost"
