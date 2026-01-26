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

# Check for existing Syzkaller config files and create default if needed
CONFIG_CHECK_DIR="$SHARED_SYZKALLER_DIR"
DEFAULT_CONFIG_FILE="$CONFIG_CHECK_DIR/syzkaller_manager.cfg"
EXISTING_CONFIGS=()
if [ -d "$CONFIG_CHECK_DIR" ]; then
    while IFS= read -r -d '' file; do
        EXISTING_CONFIGS+=("$file")
    done < <(find "$CONFIG_CHECK_DIR" -maxdepth 1 -type f -name "*.cfg" -print0 2>/dev/null || true)
fi

if [ ${#EXISTING_CONFIGS[@]} -gt 0 ]; then
    echo "Found existing Syzkaller config file(s):"
    for cfg in "${EXISTING_CONFIGS[@]}"; do
        echo "  - $(basename "$cfg")"
    done
    
    # Check if default config already exists
    if [ ! -f "$DEFAULT_CONFIG_FILE" ]; then
        # Ask user if they want to create default config
        if [ -t 0 ] && [ -z "$CI" ]; then
            echo -n "Create default config file ($(basename "$DEFAULT_CONFIG_FILE"))? [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                CREATE_DEFAULT=true
            else
                CREATE_DEFAULT=false
            fi
        else
            # Non-interactive: don't create if other configs exist
            CREATE_DEFAULT=false
            echo "  Skipping default config creation (other configs exist)."
        fi
    else
        CREATE_DEFAULT=false
        echo "  Default config already exists: $(basename "$DEFAULT_CONFIG_FILE")"
    fi
    echo
else
    # No existing configs, create default
    CREATE_DEFAULT=true
fi

# Generate default config file if needed
if [ "$CREATE_DEFAULT" = true ] && [ ! -f "$DEFAULT_CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_CHECK_DIR"
    echo "Creating default Syzkaller config file..."
    cat > "$DEFAULT_CONFIG_FILE" << EOF
{
	"target": "linux/amd64",
	"http": "127.0.0.1:56741",
	"workdir": "$CONFIG_CHECK_DIR/workdir",
	"kernel_obj": "$KERNEL_BUILD",
	"image": "$IMAGE",
	"sshkey": "$SSH_KEY",
	"syzkaller": "$SYZKALLER_BUILD_DIR",
	"procs": 8,
	"type": "qemu",
	"vm": {
		"count": 4,
		"kernel": "$KERNEL",
		"cpu": 2,
		"mem": 2048
	}
}
EOF
    echo "  Created: $(basename "$DEFAULT_CONFIG_FILE")"
    echo
fi

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
