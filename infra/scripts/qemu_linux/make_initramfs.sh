#!/bin/bash
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

INITRAMFS_DIR="/tmp/initramfs_root"
OUT_DIR="$VM_LINUX_DIR"
mkdir -p "$OUT_DIR"
rm -rf "$INITRAMFS_DIR" && mkdir -p "$INITRAMFS_DIR"/{bin,dev,proc,sys,etc,root}

# Copy static busybox
BB="$(dpkg -L busybox-static | grep -m1 -E '/busybox$')"
cp "$BB" "$INITRAMFS_DIR/bin/busybox"
file "$INITRAMFS_DIR/bin/busybox" | grep -q 'statically linked' \
  || { echo "ERROR: BusyBox is not static"; exit 1; }


# Create init script
cat << 'BB_INIT_EOF' > $INITRAMFS_DIR/init
#!/bin/busybox sh
/bin/busybox --install -s
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo "--- Booted Minimal Linux Kernel ---"
# PLACE BOOT SCRIPTS HERE
/bin/sh
BB_INIT_EOF

chmod +x $INITRAMFS_DIR/init

# Package it
cd $INITRAMFS_DIR
find . -print0 | cpio --null -ov --format=newc | gzip -9 > $OUT_DIR/initramfs.cpio.gz
echo "Initramfs created at $OUT_DIR/initramfs.cpio.gz"
