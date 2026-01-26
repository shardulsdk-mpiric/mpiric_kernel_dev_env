#!/bin/bash

# Linux Kernel QEMU Environment Setup Script
# Run this script when setting up the QEMU test environment for the first time.
#
# This script handles one-time setup tasks:
# - Installing host dependencies
# - Creating directory structure
# - Building initial initramfs
#
# The actual automation scripts are committed separately in infra/scripts/qemu_linux/

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../infra/scripts/config.sh"

echo "=== Linux Kernel QEMU Environment Setup ==="
echo "Workspace root: $KERNEL_DEV_ENV_ROOT"
echo

# 1. Host Dependencies (Ubuntu 22.04)
echo "1. Installing host dependencies..."
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils libelf-dev libssl-dev \
                    build-essential flex bison bc cpio busybox-static

# 2. Directory Structure Setup
echo "2. Creating directory structure..."
mkdir -p "$KERNEL_BUILD_DIR/mainline"
mkdir -p "$VM_LINUX_DIR"
mkdir -p "$LOG_DIR"

# 3. Build Initial Initramfs
echo "3. Building initial initramfs..."
"$SCRIPTS_QEMU_DIR/make_initramfs.sh"

echo
echo "=== Setup Complete! ==="
echo
echo "Next steps:"
echo "1. Get the Linux kernel source:"
echo "   cd $OPEN_DIR/src/kernel"
echo "   git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
echo
echo "2. Build your kernel (out-of-tree):"
echo "   cd $KERNEL_SRC_DIR"
echo "   make O=$KERNEL_BUILD_DIR/mainline defconfig"
echo "   make O=$KERNEL_BUILD_DIR/mainline -j\$(nproc)"
echo
echo "3. Boot your kernel:"
echo "   $SCRIPTS_QEMU_DIR/run_qemu_kernel.sh"
echo
echo "4. Connect via SSH (when VM is running):"
echo "   ssh -p 2222 root@localhost"
echo
echo "Scripts are located in: $SCRIPTS_QEMU_DIR"
echo "Documentation: $OPEN_DIR/vm/docs/linux/README.md"
