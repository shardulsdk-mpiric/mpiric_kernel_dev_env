#!/bin/bash

# Syzkaller Manager Runner
#
# Starts syzkaller manager with config for Debian Trixie image.
# Prerequisites: setup_syzkaller.sh, create_syzkaller_image.sh, build_syzkaller_kernel.sh.
#
# Usage: ./run_syzkaller.sh [--config /path/to/config.cfg]

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

SYZKALLER_BUILD="$SYZKALLER_BUILD_DIR"
KERNEL_BUILD="$KERNEL_BUILD_DIR/syzkaller"
IMAGE_DIR="$VM_SYZKALLER_DIR"
SHARED_DIR="$SHARED_SYZKALLER_DIR"
SCRIPTS_DIR="$SCRIPTS_SYZKALLER_DIR"

# Parse arguments
USER_CONFIG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --config) USER_CONFIG="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

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

# Default config file name
DEFAULT_CONFIG_FILE="$SHARED_DIR/syzkaller_manager.cfg"
CONFIG_FILE=""

# If user specified a config file, use it directly
if [ -n "$USER_CONFIG" ]; then
    if [ ! -f "$USER_CONFIG" ]; then
        echo "ERROR: Specified config file not found: $USER_CONFIG"
        exit 1
    fi
    CONFIG_FILE="$USER_CONFIG"
    echo "Using user-specified config: $CONFIG_FILE"
    echo
else
    # Check for existing config files
    EXISTING_CONFIGS=()
    if [ -d "$SHARED_DIR" ]; then
        while IFS= read -r -d '' file; do
            EXISTING_CONFIGS+=("$file")
        done < <(find "$SHARED_DIR" -maxdepth 1 -type f -name "*.cfg" -print0 2>/dev/null || true)
    fi

    # Handle config file selection
    if [ ${#EXISTING_CONFIGS[@]} -gt 0 ]; then
        echo "Found existing Syzkaller config file(s):"
        for cfg in "${EXISTING_CONFIGS[@]}"; do
            echo "  - $(basename "$cfg")"
        done
        echo
        
        # Check if default config already exists
        if [ -f "$DEFAULT_CONFIG_FILE" ]; then
            echo "Using existing default config: $(basename "$DEFAULT_CONFIG_FILE")"
            CONFIG_FILE="$DEFAULT_CONFIG_FILE"
        else
            # Check if running in non-interactive mode
            if [ ! -t 0 ] || [ -n "$CI" ]; then
                # Non-interactive: use first existing config
                echo "Non-interactive mode: using first existing config: $(basename "${EXISTING_CONFIGS[0]}")"
                CONFIG_FILE="${EXISTING_CONFIGS[0]}"
            else
                # Interactive: ask user if they want to create default config
                echo -n "Create default config file ($(basename "$DEFAULT_CONFIG_FILE"))? [y/N]: "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    CONFIG_FILE="$DEFAULT_CONFIG_FILE"
                else
                    # Let user choose which config to use
                    echo
                    echo "Available config files:"
                    for i in "${!EXISTING_CONFIGS[@]}"; do
                        echo "  $((i+1)). $(basename "${EXISTING_CONFIGS[$i]}")"
                    done
                    echo -n "Select config file number [1]: "
                    read -r selection
                    selection=${selection:-1}
                    if [ "$selection" -ge 1 ] && [ "$selection" -le ${#EXISTING_CONFIGS[@]} ]; then
                        CONFIG_FILE="${EXISTING_CONFIGS[$((selection-1))]}"
                    else
                        echo "ERROR: Invalid selection"
                        exit 1
                    fi
                fi
            fi
        fi
    else
        # No existing configs, create default
        CONFIG_FILE="$DEFAULT_CONFIG_FILE"
    fi

    # Generate default config file if needed and doesn't exist
    if [ "$CONFIG_FILE" = "$DEFAULT_CONFIG_FILE" ] && [ ! -f "$CONFIG_FILE" ]; then
        echo "Generating default config file: $(basename "$CONFIG_FILE")"
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
        echo "Config file created: $CONFIG_FILE"
        echo
    fi

    # Verify config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ERROR: Config file not found: $CONFIG_FILE"
        exit 1
    fi

    echo "Using config file: $CONFIG_FILE"
    echo
fi

"$SYZKALLER_BUILD/bin/syz-manager" -config "$CONFIG_FILE"

echo "Syzkaller manager stopped."
