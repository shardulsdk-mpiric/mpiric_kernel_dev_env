#!/bin/bash

# Syzkaller Manager Runner
#
# Starts syzkaller manager with config for Debian Trixie image.
# Prerequisites: setup_syzkaller.sh, create_syzkaller_image.sh, build_syzkaller_kernel.sh.

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

SYZKALLER_BUILD="$SYZKALLER_BUILD_DIR"
KERNEL_BUILD="$KERNEL_BUILD_DIR/syzkaller"
IMAGE_DIR="$VM_SYZKALLER_DIR"
SHARED_DIR="$SHARED_SYZKALLER_DIR"
SCRIPTS_DIR="$SCRIPTS_SYZKALLER_DIR"

echo "=== Starting Syzkaller ==="
echo "Manager: $SYZKALLER_BUILD/bin/syz-manager"
echo "Kernel:  $KERNEL_BUILD/arch/x86/boot/bzImage"
echo "Image:   $IMAGE_DIR/trixie.img"
echo

if [ ! -f "$SYZKALLER_BUILD/bin/syz-manager" ]; then
    echo "ERROR: syz-manager not found. Run setup_syzkaller.sh first."
    exit 1
fi

if [ ! -f "$KERNEL_BUILD/arch/x86/boot/bzImage" ]; then
    echo "ERROR: Kernel not found. Run build_syzkaller_kernel.sh first."
    exit 1
fi

if [ ! -f "$IMAGE_DIR/trixie.img" ]; then
    echo "ERROR: Debian image not found. Run create_syzkaller_image.sh first."
    exit 1
fi

mkdir -p "$SHARED_DIR/workdir"
cd "$SHARED_DIR"

# Generate config file dynamically
CONFIG_FILE="$SHARED_DIR/syzkaller_manager.cfg"
cat > "$CONFIG_FILE" << EOF
{
	"target": "linux/amd64",
	"http": "127.0.0.1:56741",
	"workdir": "$SHARED_DIR/workdir",
	"kernel_obj": "$KERNEL_BUILD",
	"image": "$IMAGE_DIR/trixie.img",
	"sshkey": "$IMAGE_DIR/trixie.id_rsa",
	"syzkaller": "$SYZKALLER_BUILD",
	"procs": 8,
	"type": "qemu",
	"vm": {
		"count": 4,
		"kernel": "$KERNEL_BUILD/arch/x86/boot/bzImage",
		"cpu": 2,
		"mem": 2048
	}
}
EOF

"$SYZKALLER_BUILD/bin/syz-manager" -config "$CONFIG_FILE"

echo "Syzkaller manager stopped."
