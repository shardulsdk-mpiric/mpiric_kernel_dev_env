#!/bin/bash
#
# Kernel Development Environment Configuration
#
# This file provides the base directory configuration for all scripts.
# It auto-detects the workspace root from the script location, or uses
# the KERNEL_DEV_ENV_ROOT environment variable if set.
#
# Usage in scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/../config.sh"  # Adjust path as needed
#

# Get the directory where this config file is located
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect workspace root: go up from infra/scripts/ to repo root
# This works regardless of where the repo is cloned
if [ -z "$KERNEL_DEV_ENV_ROOT" ]; then
    # Try to detect from config file location (infra/scripts/config.sh)
    # Go up two levels: infra/scripts/ -> infra/ -> repo root
    DETECTED_ROOT="$(cd "$CONFIG_DIR/../.." && pwd)"
    
    # Validate: check if this looks like the repo root (has infra/, open/, etc.)
    if [ -d "$DETECTED_ROOT/infra" ] && [ -d "$DETECTED_ROOT/open" ]; then
        KERNEL_DEV_ENV_ROOT="$DETECTED_ROOT"
    else
        # Fallback: use current working directory if it looks like repo root
        if [ -d "$PWD/infra" ] && [ -d "$PWD/open" ]; then
            KERNEL_DEV_ENV_ROOT="$PWD"
        else
            echo "Error: Could not detect workspace root. Set KERNEL_DEV_ENV_ROOT environment variable." >&2
            exit 1
        fi
    fi
fi

# Export the root directory
export KERNEL_DEV_ENV_ROOT

# Standard directory paths (relative to workspace root)
export OPEN_DIR="$KERNEL_DEV_ENV_ROOT/open"
export INFRA_DIR="$KERNEL_DEV_ENV_ROOT/infra"
export SHARED_DIR="$KERNEL_DEV_ENV_ROOT/shared"

# Source directories
export KERNEL_SRC_DIR="$OPEN_DIR/src/kernel/linux"
export SYZKALLER_SRC_DIR="$OPEN_DIR/src/syzkaller"

# Build directories
export KERNEL_BUILD_DIR="$OPEN_DIR/build/linux"
export SYZKALLER_BUILD_DIR="$OPEN_DIR/build/syzkaller"

# VM/runtime directories
export VM_LINUX_DIR="$OPEN_DIR/vm/linux"
export VM_SYZKALLER_DIR="$OPEN_DIR/vm/syzkaller"

# Log directories
export LOG_DIR="$OPEN_DIR/logs/qemu"

# Script directories
export SCRIPTS_QEMU_DIR="$INFRA_DIR/scripts/qemu_linux"
export SCRIPTS_SYZKALLER_DIR="$INFRA_DIR/scripts/syzkaller"

# Shared Syzkaller directories
export SHARED_SYZKALLER_DIR="$SHARED_DIR/syzkaller"

# Kernel build environment variables (commonly used in kernel development)
# KSRCDIR: Kernel source directory
export KSRCDIR="$KERNEL_SRC_DIR"

# KBUILDDIR: Kernel build directory with timestamped prefix
# Users can override this by setting KBUILDDIR before sourcing config.sh
# Format: YYYY_MM_DD_HHMMSS_<profile>
if [ -z "$KBUILDDIR" ]; then
    TIMESTAMP=$(date +"%Y_%m_%d_%H%M%S")
    BUILD_PROFILE="${BUILD_PROFILE:-mainline}"
    export KBUILDDIR="$KERNEL_BUILD_DIR/${TIMESTAMP}_${BUILD_PROFILE}"
else
    # KBUILDDIR already set by user, export it
    export KBUILDDIR
fi

# Function to print all environment variables set by this config
# Usage: source infra/scripts/config.sh && printvars
printvars() {
    echo "=== Kernel Development Environment Variables ==="
    echo
    echo "Workspace Configuration:"
    echo "  KERNEL_DEV_ENV_ROOT=$KERNEL_DEV_ENV_ROOT"
    echo
    echo "Directory Paths:"
    echo "  OPEN_DIR=$OPEN_DIR"
    echo "  INFRA_DIR=$INFRA_DIR"
    echo "  SHARED_DIR=$SHARED_DIR"
    echo
    echo "Source Directories:"
    echo "  KERNEL_SRC_DIR=$KERNEL_SRC_DIR"
    echo "  SYZKALLER_SRC_DIR=$SYZKALLER_SRC_DIR"
    echo
    echo "Build Directories:"
    echo "  KERNEL_BUILD_DIR=$KERNEL_BUILD_DIR"
    echo "  SYZKALLER_BUILD_DIR=$SYZKALLER_BUILD_DIR"
    echo
    echo "VM/Runtime Directories:"
    echo "  VM_LINUX_DIR=$VM_LINUX_DIR"
    echo "  VM_SYZKALLER_DIR=$VM_SYZKALLER_DIR"
    echo
    echo "Log Directories:"
    echo "  LOG_DIR=$LOG_DIR"
    echo
    echo "Script Directories:"
    echo "  SCRIPTS_QEMU_DIR=$SCRIPTS_QEMU_DIR"
    echo "  SCRIPTS_SYZKALLER_DIR=$SCRIPTS_SYZKALLER_DIR"
    echo
    echo "Shared Directories:"
    echo "  SHARED_SYZKALLER_DIR=$SHARED_SYZKALLER_DIR"
    echo
    echo "Kernel Build Environment:"
    echo "  KSRCDIR=$KSRCDIR"
    echo "  KBUILDDIR=$KBUILDDIR"
    echo
    echo "Build Profile:"
    echo "  BUILD_PROFILE=${BUILD_PROFILE:-mainline}"
    echo
    echo "=== End of Variables ==="
}

