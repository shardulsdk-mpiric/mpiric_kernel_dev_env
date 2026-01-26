#!/bin/bash

# Build Linux Kernel for Syzkaller Compatibility
#
# Follows official Syzkaller Ubuntu/QEMU setup:
# https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md
#
# Uses defconfig + kvm_guest.config and enables KCOV, KASAN, DEBUG_INFO_DWARF4.
# Kernel is built for Debian Trixie disk image (root=/dev/sda, net.ifnames=0).

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

SRC_DIR="$KERNEL_SRC_DIR"
BUILD_DIR="$KERNEL_BUILD_DIR/syzkaller"

echo "=== Building Syzkaller-Compatible Kernel ==="
echo "Source: $SRC_DIR"
echo "Build: $BUILD_DIR"
echo

mkdir -p "$BUILD_DIR"

echo "Configuring kernel (defconfig + kvm_guest.config)..."
make -C "$SRC_DIR" O="$BUILD_DIR" defconfig
make -C "$SRC_DIR" O="$BUILD_DIR" kvm_guest.config

echo "Enabling Syzkaller-required options..."
# Per official docs: KCOV, DEBUG_INFO_DWARF4, KASAN, CONFIGFS_FS, SECURITYFS
# CMDLINE for Debian image: root=/dev/sda, net.ifnames=0
"$SRC_DIR/scripts/config" --file "$BUILD_DIR/.config" \
    -e KCOV \
    -e DEBUG_INFO \
    -e DEBUG_INFO_DWARF4 \
    -e KASAN \
    -e KASAN_INLINE \
    -e CONFIGFS_FS \
    -e SECURITYFS \
    -e CMDLINE_BOOL

# Set cmdline for Debian Trixie image (root=/dev/sda)
sed -i 's/^CONFIG_CMDLINE=.*/CONFIG_CMDLINE="console=ttyS0 root=\/dev\/sda earlyprintk=serial net.ifnames=0"/' "$BUILD_DIR/.config" 2>/dev/null || \
    echo 'CONFIG_CMDLINE="console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0"' >> "$BUILD_DIR/.config"

make -C "$SRC_DIR" O="$BUILD_DIR" olddefconfig

echo "Building kernel..."
make -C "$SRC_DIR" O="$BUILD_DIR" -j"$(nproc)"

echo "Syzkaller kernel built successfully!"
echo "Kernel: $BUILD_DIR/arch/x86/boot/bzImage"
echo "vmlinux: $BUILD_DIR/vmlinux"
echo
echo "To test: $SCRIPTS_SYZKALLER_DIR/run_qemu_syzkaller.sh"
