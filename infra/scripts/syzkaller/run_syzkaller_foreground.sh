#!/bin/bash
#
# Run syz-manager in the foreground (no screen, no log rotation).
#
# Use this for one-off runs or debugging. For long-running fuzzing in a detached
# session with log rotation, use start_syzkaller_manager.sh instead.
#
# Prerequisites: setup_syzkaller.sh, create_syzkaller_image.sh, build_syzkaller_kernel.sh
# (or set KBUILDDIR to your kernel build directory).
#
# Usage: ./run_syzkaller_foreground.sh [--config /path/to/config.cfg]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"
source "$SCRIPT_DIR/syzkaller_common.sh"

KERNEL_BUILD="$(get_syzkaller_kernel_build_dir)"

echo "=== Starting Syzkaller (foreground) ==="
echo "Manager: $SYZKALLER_BUILD_DIR/bin/syz-manager"
echo "Kernel:  $KERNEL_BUILD/arch/x86/boot/bzImage"
echo "Image:   $VM_SYZKALLER_DIR/trixie.img"
echo

check_syzkaller_prerequisites "$KERNEL_BUILD"

mkdir -p "$SHARED_SYZKALLER_DIR/workdir"
cd "$SHARED_SYZKALLER_DIR"

select_or_create_syzkaller_config "$@"  # passes through --config if given

"$SYZKALLER_BUILD_DIR/bin/syz-manager" -config "$CONFIG_FILE"

echo "Syzkaller manager stopped."
