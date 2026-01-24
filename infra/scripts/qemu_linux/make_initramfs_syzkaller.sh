#!/bin/bash

# Enhanced Initramfs Builder for Syzkaller
# Creates initramfs with automatic shared directory mounting and Syzkaller setup
#
# Usage: ./make_initramfs_syzkaller.sh [--shared-dir path]

set -e

# Configuration
INITRAMFS_DIR="/tmp/initramfs_syzkaller"
OUT_DIR="/mnt/dev_ext_4tb/open/vm/linux"
SHARED_DIR="/mnt/dev_ext_4tb/shared"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --shared-dir) SHARED_DIR="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "Building Syzkaller-enhanced initramfs..."
echo "Output: $OUT_DIR/initramfs_syzkaller.cpio.gz"
echo "Shared dir: $SHARED_DIR"
echo

# Clean up previous build
rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"/{bin,dev,proc,sys,etc,root,mnt/host}

# Copy busybox
echo "Setting up BusyBox..."
BB="$(dpkg -L busybox-static | grep -m1 -E '/busybox$')"
cp "$BB" "$INITRAMFS_DIR/bin/busybox"
file "$INITRAMFS_DIR/bin/busybox" | grep -q 'statically linked' \
  || { echo "ERROR: BusyBox is not static"; exit 1; }

# Create enhanced init script with Syzkaller setup
echo "Creating init script with Syzkaller integration..."
cat > "$INITRAMFS_DIR/init" << EOF
#!/bin/busybox sh

# Enhanced init script for Syzkaller testing
/bin/busybox --install -s

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Mount shared directory (if available)
echo "Attempting to mount shared directory..."
if mount -t 9p -o trans=virtio hostshare /mnt/host 2>/dev/null; then
    echo "✓ Shared directory mounted at /mnt/host"

    # Set up Syzkaller environment if binaries are available
    if [ -d "/mnt/host/syzkaller/bin" ]; then
        echo "✓ Syzkaller binaries found, setting up environment..."

        # Create symlinks for easy access
        mkdir -p /usr/local/bin
        for bin in /mnt/host/syzkaller/bin/*; do
            if [ -x "\$bin" ]; then
                ln -sf "\$bin" "/usr/local/bin/\$(basename \$bin)"
            fi
        done

        # Set up working directory
        mkdir -p /mnt/host/syzkaller/workdir
        mkdir -p /mnt/host/syzkaller/corpus
        mkdir -p /mnt/host/syzkaller/crashes

        echo "✓ Syzkaller environment ready"
        echo "  Binaries: /usr/local/bin/"
        echo "  Workdir: /mnt/host/syzkaller/workdir/"
        echo "  Corpus: /mnt/host/syzkaller/corpus/"
        echo "  Crashes: /mnt/host/syzkaller/crashes/"
        echo
        echo "🚀 Syzkaller VM Ready!"
        echo "   Run 'syz-manager --help' to get started"
        echo
    else
        echo "⚠ Shared directory mounted but Syzkaller binaries not found"
        echo "  Expected at: /mnt/host/syzkaller/bin/"
    fi
else
    echo "⚠ Shared directory not available (9p mount failed)"
    echo "  This is normal if not using Syzkaller setup"
fi

echo "--- Linux Kernel Test Environment ---"
echo "Root filesystem: initramfs (RAM)"
echo "Available commands: \$(busybox --list)"
echo
echo "Useful commands:"
echo "  ls /mnt/host/     # Access shared directory (if mounted)"
echo "  syz-manager       # Run Syzkaller (if available)"
echo "  dmesg | tail      # Check kernel messages"
echo "  ps aux            # Process list"
echo "  /bin/sh           # Interactive shell"
echo

# Start shell
exec /bin/sh
EOF

chmod +x "$INITRAMFS_DIR/init"

# Package the initramfs
echo "Packaging initramfs..."
cd "$INITRAMFS_DIR"
find . -print0 | cpio --null -ov --format=newc | gzip -9 > "$OUT_DIR/initramfs_syzkaller.cpio.gz"

echo "✓ Syzkaller-enhanced initramfs created: $OUT_DIR/initramfs_syzkaller.cpio.gz"
echo
echo "Features:"
echo "  • Automatic shared directory mounting (/mnt/host)"
echo "  • Syzkaller binary auto-detection and setup"
echo "  • Symlinks in /usr/local/bin/ for easy access"
echo "  • Working directory setup in shared folder"
echo
echo "To use with Syzkaller:"
echo "  1. Run: /mnt/dev_ext_4tb/infra/scripts/syzkaller/setup_syzkaller.sh"
echo "  2. Boot: /mnt/dev_ext_4tb/infra/scripts/syzkaller/run_qemu_syzkaller.sh"
echo
echo "To use standard initramfs:"
echo "  /mnt/dev_ext_4tb/infra/scripts/qemu_linux/run_qemu_kernel.sh"