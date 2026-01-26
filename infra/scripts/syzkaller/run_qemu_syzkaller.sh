#!/bin/bash

# QEMU Syzkaller Integration Script
#
# Boots kernel with Syzkaller Debian Trixie disk image, per official setup:
# https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md
#
# Usage: ./run_qemu_syzkaller.sh [--kernel path] [--image path] [--ssh-port port]

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

KERNEL_BUILD="$KERNEL_BUILD_DIR/syzkaller"
KERNEL="$KERNEL_BUILD/arch/x86/boot/bzImage"
IMAGE="$VM_SYZKALLER_DIR/trixie.img"
SSH_KEY="$VM_SYZKALLER_DIR/trixie.id_rsa"
SSH_PORT="10021"
MEM="2G"
CPUS="2"

while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel) KERNEL="$2"; shift ;;
        --image)  IMAGE="$2"; SSH_KEY="${2%.img}.id_rsa"; shift ;;
        --ssh-port) SSH_PORT="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    echo "Run build_syzkaller_kernel.sh first."
    exit 1
fi

if [ ! -f "$IMAGE" ]; then
    echo "Error: Image not found at $IMAGE"
    echo "Run create_syzkaller_image.sh first."
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found at $SSH_KEY"
    echo "Run create_syzkaller_image.sh first."
    exit 1
fi

mkdir -p "$LOG_DIR"

echo "Booting Syzkaller kernel: $KERNEL"
echo "Image: $IMAGE"
echo "Shared: $SHARED_DIR (9p → /mnt/host in guest)"
echo "SSH: ssh -i $SSH_KEY -p $SSH_PORT -o StrictHostKeyChecking=no root@localhost"
echo "Log: $LOG_DIR/qemu_syzkaller_$(date +%s).log"
echo

# Per official docs: -drive, -net user hostfwd, -net nic e1000
# -virtfs: always mount shared dir (guest auto-mounts at /mnt/host via systemd)
qemu-system-x86_64 \
    -m "$MEM" \
    -smp "$CPUS" \
    -kernel "$KERNEL" \
    -append "console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0" \
    -drive "file=$IMAGE,format=raw" \
    -net "user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
    -net "nic,model=e1000" \
    -virtfs "local,path=$SHARED_DIR,mount_tag=hostshare,security_model=mapped,id=hostshare" \
    -enable-kvm -cpu host \
    -nographic \
    -pidfile "$VM_SYZKALLER_DIR/vm.pid" \
    2>&1 | tee "$LOG_DIR/qemu_syzkaller_$(date +%s).log"
