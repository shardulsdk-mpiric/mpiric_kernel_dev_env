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

echo "=== Linux Kernel QEMU Environment Setup ==="
echo

# 1. Host Dependencies (Ubuntu 22.04)
echo "1. Installing host dependencies..."
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils libelf-dev libssl-dev \
                    build-essential flex bison bc cpio busybox-static

# 2. Directory Structure Setup
echo "2. Creating directory structure..."
mkdir -p /mnt/dev_ext_4tb/open/build/linux/mainline
mkdir -p /mnt/dev_ext_4tb/open/vm/linux
mkdir -p /mnt/dev_ext_4tb/open/logs/qemu/

# 3. Build Initial Initramfs
echo "3. Building initial initramfs..."
/mnt/dev_ext_4tb/infra/scripts/qemu_linux/make_initramfs.sh

echo
echo "=== Setup Complete! ==="
echo
echo "Next steps:"
echo "1. Build your kernel (out-of-tree):"
echo "   cd /mnt/dev_ext_4tb/open/src/kernel/linux"
echo "   make O=/mnt/dev_ext_4tb/open/build/linux/mainline defconfig"
echo "   make O=/mnt/dev_ext_4tb/open/build/linux/mainline -j$(nproc)"
echo
echo "2. Boot your kernel:"
echo "   /mnt/dev_ext_4tb/infra/scripts/qemu_linux/run_qemu_kernel.sh"
echo
echo "3. Connect via SSH (when VM is running):"
echo "   ssh -p 2222 root@localhost"
echo
echo "Scripts are located in: /mnt/dev_ext_4tb/infra/scripts/qemu_linux/"
echo "Documentation: /mnt/dev_ext_4tb/open/vm/docs/linux/README.md"
