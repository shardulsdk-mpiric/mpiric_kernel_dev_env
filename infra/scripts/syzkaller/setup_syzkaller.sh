#!/bin/bash
#
# Syzkaller Setup Script
#
# Copyright (C) 2026 Linux Kernel Development Team
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Syzkaller Setup Script
# Downloads, builds Syzkaller and creates Debian Trixie image.
# Automation scripts are committed separately; this script does not generate them.

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

SYZKALLER_VERSION="${SYZKALLER_VERSION:-master}"
SRC_DIR="$SYZKALLER_SRC_DIR"
BUILD_DIR="$SYZKALLER_BUILD_DIR"
SHARED_DIR="$SHARED_SYZKALLER_DIR"
IMAGE_DIR="$VM_SYZKALLER_DIR"
SCRIPTS_DIR="$SCRIPTS_SYZKALLER_DIR"

echo "=== Syzkaller Setup ==="
echo "Source: $SRC_DIR"
echo "Build: $BUILD_DIR"
echo "Image:  $IMAGE_DIR"
echo "Shared: $SHARED_DIR"
echo

echo "1. Creating directories..."
mkdir -p "$SRC_DIR" "$BUILD_DIR/bin" "$SHARED_DIR/workdir" "$SHARED_DIR/corpus" "$SHARED_DIR/crashes" "$IMAGE_DIR"

# Check for existing Syzkaller config files and create default if needed
DEFAULT_CONFIG_FILE="$SHARED_DIR/syzkaller_manager.cfg"
EXISTING_CONFIGS=()
if [ -d "$SHARED_DIR" ]; then
    while IFS= read -r -d '' file; do
        EXISTING_CONFIGS+=("$file")
    done < <(find "$SHARED_DIR" -maxdepth 1 -type f -name "*.cfg" -print0 2>/dev/null || true)
fi

if [ ${#EXISTING_CONFIGS[@]} -gt 0 ]; then
    echo
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
    # Need kernel build path for config - use a placeholder that will be updated
    KERNEL_BUILD_PLACEHOLDER="$KERNEL_BUILD_DIR/syzkaller"
    echo "Creating default Syzkaller config file..."
    cat > "$DEFAULT_CONFIG_FILE" << EOF
{
	"target": "linux/amd64",
	"http": "127.0.0.1:56741",
	"workdir": "$SHARED_DIR/workdir",
	"kernel_obj": "$KERNEL_BUILD_PLACEHOLDER",
	"image": "$IMAGE_DIR/trixie.img",
	"sshkey": "$IMAGE_DIR/trixie.id_rsa",
	"syzkaller": "$BUILD_DIR",
	"procs": 8,
	"type": "qemu",
	"vm": {
		"count": 4,
		"kernel": "$KERNEL_BUILD_PLACEHOLDER/arch/x86/boot/bzImage",
		"cpu": 2,
		"mem": 2048
	}
}
EOF
    echo "  Created: $(basename "$DEFAULT_CONFIG_FILE")"
    echo "  Note: Update kernel_obj and vm.kernel paths after building the kernel."
    echo
fi

echo "2. Installing dependencies..."
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    sudo apt update && sudo apt install -y golang-go
fi
sudo apt install -y build-essential debootstrap qemu-system-x86 qemu-utils \
    flex bison libc6-dev libc6-dev-i386 linux-libc-dev linux-libc-dev:i386 \
    libgmp3-dev libmpfr-dev libmpc-dev bc git

echo "3. Downloading Syzkaller source..."
if [ -d "$SRC_DIR/.git" ]; then
    cd "$SRC_DIR"
    CURRENT_BRANCH=$(git branch --show-current)
    if [ -z "$CURRENT_BRANCH" ]; then
        if git show-ref --verify -q refs/heads/master; then git checkout master
        elif git show-ref --verify -q refs/heads/main; then git checkout main
        else echo "ERROR: No master/main branch"; exit 1; fi
    fi
    git pull
else
    git clone https://github.com/google/syzkaller.git "$SRC_DIR"
    cd "$SRC_DIR"
    [ "$SYZKALLER_VERSION" != "master" ] && git checkout "$SYZKALLER_VERSION"
fi

echo "4. Building Syzkaller (syz-env)..."
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker required. Install: https://docs.docker.com/engine/install/"
    exit 1
fi
if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon not running. Start: sudo systemctl start docker"
    exit 1
fi
cd "$SRC_DIR"
./tools/syz-env make -j"$(nproc)"

echo "5. Installing binaries..."
rm -rf "$BUILD_DIR/bin"
cp -r "$SRC_DIR/bin" "$BUILD_DIR/"
if [ ! -f "$BUILD_DIR/bin/syz-manager" ]; then
    echo "ERROR: syz-manager not found after build"; exit 1
fi

echo "6. Creating Debian Trixie image..."
"$SCRIPTS_DIR/create_syzkaller_image.sh"

echo
echo "=== Syzkaller Setup Complete ==="
echo "Next steps:"
echo "  1. Build kernel:  $SCRIPTS_DIR/build_syzkaller_kernel.sh"
echo "  2. Boot QEMU:     $SCRIPTS_DIR/run_qemu_syzkaller.sh"
echo "  3. Run fuzzer:    $SCRIPTS_DIR/start_syzkaller_manager.sh -config <path-to-cfg>  (or run_syzkaller_foreground.sh for one-off)"
echo "  4. SSH to guest:  ssh -i $IMAGE_DIR/trixie.id_rsa -p 10021 -o StrictHostKeyChecking=no root@localhost"
echo "See: $OPEN_DIR/vm/docs/linux/setup_syzkaller.md"
