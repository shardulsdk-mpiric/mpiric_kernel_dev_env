#!/bin/bash

# Run this script when you are setting up the qemu test environment for the
# first time.

# Exports
export SCRIPTS=/mnt/dev_ext_4tb/infra/scripts/qemu_linux

# 1. Host Dependencies (Ubuntu 22.04)
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils libelf-dev libssl-dev \
                    build-essential flex bison bc cpio busybox-static

# 2. Directory Structure Setup
# Ensure your layout exists:
mkdir -p /mnt/dev_ext_4tb/open/build/linux/mainline
mkdir -p /mnt/dev_ext_4tb/open/vm/linux
mkdir -p /mnt/dev_ext_4tb/infra/scripts/qemu_linux
mkdir -p /mnt/dev_ext_4tb/open/logs/qemu/

# 3. The "Minimal" Rootfs Helper
# This script creates a tiny BusyBox initramfs. It includes an init script that allows you to run commands at boot.
# File: $SCRIPTS/make_initramfs.sh

cat << '__MAKE_INITRAMFS__' > "$SCRIPTS/make_initramfs.sh"
#!/bin/bash
set -e
INITRAMFS_DIR="/tmp/initramfs_root"
OUT_DIR="/mnt/dev_ext_4tb/open/vm/linux"
rm -rf $INITRAMFS_DIR && mkdir -p $INITRAMFS_DIR/{bin,dev,proc,sys,etc,root}

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
__MAKE_INITRAMFS__

chmod +x $SCRIPTS/make_initramfs.sh
$SCRIPTS/make_initramfs.sh

# _______________________________________________
# 4. Building the Kernel (Out-of-Tree)

# Run this from your source directory ($SRC/kernel/linux):
# 1. Configure
# make O=$BUILD/linux/mainline defconfig

# 2. Enable specific KVM/Virtio flags for QEMU performance
# (Optional but recommended: manually edit .config or use scripts/config)

# 3. Build
# make O=$BUILD/linux/mainline -j$(nproc)

# The artifact will be at: $BUILD/linux/mainline/arch/x86/boot/bzImage.

# _______________________________________________

# 5. The Main Automation Script
# This script handles the QEMU logic, argument parsing, and logging.
# File: $SCRIPTS/run_qemu_kernel.sh

cat << 'QEMU_SCRIPT_EOF' > "$SCRIPTS/run_qemu_kernel.sh"
#!/bin/bash

# Defaults
DISK="/mnt/dev_ext_4tb"
BUILD_DIR="$DISK/open/build/linux/mainline"
VM_DIR="$DISK/open/vm/linux"
LOG_DIR="$DISK/open/logs/qemu"
KERNEL="$BUILD_DIR/arch/x86/boot/bzImage"
INITRD="$VM_DIR/initramfs.cpio.gz"
MEM="2G"
CPUS="2"
SSH_PORT="2222"
SNAPSHOT=""

# Argument Parsing
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --kernel) KERNEL="$2"; shift ;;
        --rootfs) INITRD="$2"; shift ;;
        --ssh-forward) SSH_PORT="$2"; shift ;;
        --snapshot) SNAPSHOT="-snapshot" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Ensure Kernel exists
if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    exit 1
fi

# QEMU Command
QEMU_CMD="qemu-system-x86_64 \
    -m $MEM \
    -smp $CPUS \
    -kernel $KERNEL \
    -initrd $INITRD \
    -nographic \
    -append \"console=ttyS0 root=/dev/ram0 rw\" \
    -enable-kvm -cpu host \
    -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22 -device virtio-net-pci,netdev=net0 \
    -serial mon:stdio \
    $SNAPSHOT"

echo "Booting Kernel: $KERNEL"
echo "Logging to: $LOG_DIR/qemu_$(date +%F_%T).log"

# Run and Log
eval "$QEMU_CMD" | tee "$LOG_DIR/qemu_$(date +%s).log"
QEMU_SCRIPT_EOF

chmod +x $SCRIPTS/run_qemu_kernel.sh
