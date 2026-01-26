#!/bin/bash

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# Defaults
BUILD_DIR="$KERNEL_BUILD_DIR/mainline"
KERNEL="$BUILD_DIR/arch/x86/boot/bzImage"
INITRD="$VM_LINUX_DIR/initramfs.cpio.gz"
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

mkdir -p "$LOG_DIR"
echo "Booting Kernel: $KERNEL"
echo "Logging to: $LOG_DIR/qemu_$(date +%F_%T).log"

# Run and Log
eval "$QEMU_CMD" | tee "$LOG_DIR/qemu_$(date +%s).log"
