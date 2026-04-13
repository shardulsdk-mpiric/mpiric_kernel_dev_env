#!/bin/bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

usage() {
    echo "Usage: $(basename "$0") --size <amount> [--image <path>]"
    echo ""
    echo "Grow a VM rootfs image by the specified amount and resize the filesystem."
    echo "The VM must be shut down before running this."
    echo ""
    echo "Options:"
    echo "  --size   Amount to grow by (e.g., 2G, 512M, 4G)"
    echo "  --image  Path to rootfs image (default: \$VM_SYZKALLER_DIR/trixie.img)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") --size 4G"
    echo "  $(basename "$0") --size 2G --image /path/to/custom.img"
    exit 1
}

IMAGE="$VM_SYZKALLER_DIR/trixie.img"
GROW_SIZE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --size) GROW_SIZE="$2"; shift ;;
        --image) IMAGE="$2"; shift ;;
        --help|-h) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

if [ -z "$GROW_SIZE" ]; then
    echo "Error: --size is required"
    usage
fi

if [ ! -f "$IMAGE" ]; then
    echo "Error: Image not found at $IMAGE"
    exit 1
fi

# Check that no QEMU process is using this image
if fuser "$IMAGE" 2>/dev/null; then
    echo "Error: Image is in use (VM likely running). Shut down the VM first."
    exit 1
fi

BEFORE=$(stat --printf="%s" "$IMAGE")
BEFORE_HUMAN=$(numfmt --to=iec "$BEFORE")

echo "Image:  $IMAGE"
echo "Before: $BEFORE_HUMAN"
echo "Growing by: $GROW_SIZE"

truncate -s +"$GROW_SIZE" "$IMAGE"

AFTER=$(stat --printf="%s" "$IMAGE")
AFTER_HUMAN=$(numfmt --to=iec "$AFTER")
echo "After:  $AFTER_HUMAN"

echo ""
echo "Running e2fsck..."
e2fsck -f "$IMAGE"

echo ""
echo "Resizing filesystem..."
resize2fs "$IMAGE"

echo ""
echo "Done. Boot the VM to verify with: df -h"
