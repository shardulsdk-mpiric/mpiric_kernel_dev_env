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
echo "  3. Run fuzzer:    $SCRIPTS_DIR/run_syzkaller.sh"
echo "  4. SSH to guest:  ssh -i $IMAGE_DIR/trixie.id_rsa -p 10021 -o StrictHostKeyChecking=no root@localhost"
echo "See: $BASE_DIR/open/vm/docs/linux/setup_syzkaller.md"
