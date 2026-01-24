#!/bin/bash

# Syzkaller Setup Script
# Downloads, builds, and configures Syzkaller for Linux kernel fuzzing
#
# This script:
# 1. Downloads Syzkaller source code
# 2. Installs required dependencies (Go, build tools)
# 3. Builds Syzkaller binaries
# 4. Creates QEMU integration scripts
# 5. Sets up shared directory for guest access

set -e

# Configuration
SYZKALLER_VERSION="master"  # or specific tag like "v4.0"
BASE_DIR="/mnt/dev_ext_4tb"
SRC_DIR="$BASE_DIR/open/src/syzkaller"
BUILD_DIR="$BASE_DIR/open/build/syzkaller"
SHARED_DIR="$BASE_DIR/shared/syzkaller"
SCRIPTS_DIR="$BASE_DIR/infra/scripts/syzkaller"

echo "=== Syzkaller Setup ==="
echo "Source: $SRC_DIR"
echo "Build: $BUILD_DIR"
echo "Shared: $SHARED_DIR"
echo

# Create directories
echo "1. Creating directories..."
mkdir -p "$SRC_DIR"
mkdir -p "$BUILD_DIR/bin"
mkdir -p "$SHARED_DIR"
mkdir -p "$SCRIPTS_DIR"

# Install dependencies
echo "2. Installing dependencies..."

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    sudo apt update
    sudo apt install -y golang-go
fi

# Additional build dependencies for Syzkaller
sudo apt install -y \
    build-essential \
    debootstrap \
    qemu-system-x86 \
    qemu-utils \
    flex \
    bison \
    libc6-dev \
    libc6-dev-i386 \
    linux-libc-dev \
    linux-libc-dev:i386 \
    libgmp3-dev \
    libmpfr-dev \
    libmpc-dev \
    bc \
    git

# Download Syzkaller source
echo "3. Downloading Syzkaller source..."
if [ -d "$SRC_DIR/.git" ]; then
    echo "Syzkaller source already exists, updating..."
    cd "$SRC_DIR"
    git pull
else
    echo "Cloning Syzkaller repository..."
    git clone https://github.com/google/syzkaller.git "$SRC_DIR"
    cd "$SRC_DIR"
    if [ "$SYZKALLER_VERSION" != "master" ]; then
        git checkout "$SYZKALLER_VERSION"
    fi
fi

# Build Syzkaller
echo "4. Building Syzkaller..."
cd "$SRC_DIR"

# Use all available CPU cores for build
export GOPROXY=https://proxy.golang.org,direct
make -j"$(nproc)"

# Install binaries to build directory
echo "5. Installing binaries..."
cp -r bin/* "$BUILD_DIR/bin/"

# Verify build
echo "6. Verifying build..."
if [ ! -f "$BUILD_DIR/bin/syz-manager" ]; then
    echo "ERROR: syz-manager not found after build"
    exit 1
fi

if [ ! -f "$BUILD_DIR/bin/syz-fuzzer" ]; then
    echo "ERROR: syz-fuzzer not found after build"
    exit 1
fi

# Create shared directory structure
echo "7. Setting up shared directory..."
mkdir -p "$SHARED_DIR/bin"
mkdir -p "$SHARED_DIR/workdir"
mkdir -p "$SHARED_DIR/corpus"
mkdir -p "$SHARED_DIR/crashes"

# Copy binaries to shared directory for guest access
cp -r "$BUILD_DIR/bin/"* "$SHARED_DIR/bin/"

# Build Syzkaller-enhanced initramfs
echo "8. Building Syzkaller-enhanced initramfs..."
"$SCRIPTS_DIR/../qemu_linux/make_initramfs_syzkaller.sh" --shared-dir "$BASE_DIR/shared"

# Create QEMU integration script
echo "9. Creating QEMU integration script..."
cat > "$SCRIPTS_DIR/run_qemu_syzkaller.sh" << 'EOF'
#!/bin/bash

# QEMU Syzkaller Integration Script
# Boots kernel with Syzkaller binaries available in guest VM
#
# Usage: ./run_qemu_syzkaller.sh [--kernel path] [--config path]

set -e

# Defaults
DISK="/mnt/dev_ext_4tb"
BUILD_DIR="$DISK/open/build/linux/syzkaller"
VM_DIR="$DISK/open/vm/linux"
SHARED_DIR="$DISK/shared"
LOG_DIR="$DISK/open/logs/qemu"
KERNEL="$BUILD_DIR/arch/x86/boot/bzImage"
INITRD="$VM_DIR/initramfs.cpio.gz"
MEM="4G"  # More memory for fuzzing
CPUS="4"  # More CPUs for fuzzing
SSH_PORT="2223"  # Different port for syzkaller VM
SNAPSHOT=""

# Argument parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel) KERNEL="$2"; shift ;;
        --rootfs) INITRD="$2"; shift ;;
        --ssh-forward) SSH_PORT="$2"; shift ;;
        --snapshot) SNAPSHOT="-snapshot" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Ensure kernel exists
if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    echo "Make sure to build a syzkaller-compatible kernel first."
    exit 1
fi

# QEMU Command with 9p shared directory
QEMU_CMD="qemu-system-x86_64 \
    -m $MEM \
    -smp $CPUS \
    -kernel $KERNEL \
    -initrd $INITRD \
    -nographic \
    -append \"console=ttyS0 root=/dev/ram0 rw\" \
    -enable-kvm -cpu host \
    -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22 -device virtio-net-pci,netdev=net0 \
    -virtfs local,path=$SHARED_DIR,mount_tag=hostshare,security_model=mapped,id=hostshare \
    -serial mon:stdio \
    $SNAPSHOT"

echo "Booting Syzkaller Kernel: $KERNEL"
echo "Shared directory: $SHARED_DIR"
echo "SSH port: $SSH_PORT"
echo "Logging to: $LOG_DIR/qemu_syzkaller_$(date +%F_%T).log"
echo
echo "In guest VM, mount shared directory:"
echo "  mkdir -p /mnt/host"
echo "  mount -t 9p -o trans=virtio hostshare /mnt/host"
echo
echo "Syzkaller binaries will be available at: /mnt/host/syzkaller/bin/"
echo

# Run and log
eval "$QEMU_CMD" | tee "$LOG_DIR/qemu_syzkaller_$(date +%s).log"
EOF

chmod +x "$SCRIPTS_DIR/run_qemu_syzkaller.sh"

# Create Syzkaller manager configuration
echo "10. Creating Syzkaller manager configuration..."
cat > "$SCRIPTS_DIR/syzkaller_manager.cfg" << EOF
{
    "target": "linux/amd64",
    "http": "127.0.0.1:56741",
    "workdir": "$SHARED_DIR/workdir",
    "kernel_obj": "$BUILD_DIR/vmlinux",
    "syzkaller": "$BUILD_DIR/bin",
    "corpus": "$SHARED_DIR/corpus",
    "result": "$SHARED_DIR/crashes",
    "type": "qemu",
    "qemu": "$BUILD_DIR/arch/x86/boot/bzImage",
    "qemu_args": "-m 4G -smp 4 -enable-kvm -cpu host",
    "enable_syscalls": [
        "openat\$dfd",
        "read",
        "write",
        "close"
    ],
    "disable_syscalls": [],
    "sandbox": "namespace",
    "procs": 4,
    "leak": false,
    "cover": true
}
EOF

# Create Syzkaller runner script
echo "11. Creating Syzkaller runner script..."
cat > "$SCRIPTS_DIR/run_syzkaller.sh" << EOF
#!/bin/bash

# Syzkaller Runner Script
# Starts syzkaller manager with QEMU integration
#
# Prerequisites:
# - Syzkaller-compatible kernel built and available
# - QEMU VM running with shared directory mounted
# - SSH access configured

set -e

BASE_DIR="/mnt/dev_ext_4tb"
BUILD_DIR="\$BASE_DIR/open/build/syzkaller"
SHARED_DIR="\$BASE_DIR/shared/syzkaller"
SCRIPTS_DIR="\$BASE_DIR/infra/scripts/syzkaller"

echo "=== Starting Syzkaller Fuzzing ==="
echo "Build dir: \$BUILD_DIR"
echo "Shared dir: \$SHARED_DIR"
echo

# Check prerequisites
if [ ! -f "\$BUILD_DIR/bin/syz-manager" ]; then
    echo "ERROR: syz-manager not found. Run setup_syzkaller.sh first."
    exit 1
fi

if [ ! -f "\$BUILD_DIR/arch/x86/boot/bzImage" ]; then
    echo "ERROR: Syzkaller kernel not found at \$BUILD_DIR/arch/x86/boot/bzImage"
    echo "Build a syzkaller-compatible kernel first."
    exit 1
fi

# Start syzkaller manager
echo "Starting syzkaller manager..."
cd "\$SHARED_DIR"
"\$BUILD_DIR/bin/syz-manager" -config "\$SCRIPTS_DIR/syzkaller_manager.cfg"

echo "Syzkaller manager stopped."
EOF

chmod +x "$SCRIPTS_DIR/run_syzkaller.sh"

# Create kernel build script for Syzkaller compatibility
echo "12. Creating Syzkaller kernel build script..."
cat > "$SCRIPTS_DIR/build_syzkaller_kernel.sh" << EOF
#!/bin/bash

# Build Linux Kernel for Syzkaller Compatibility
# Enables required config options for fuzzing

set -e

BASE_DIR="/mnt/dev_ext_4tb"
SRC_DIR="\$BASE_DIR/open/src/kernel/linux"
BUILD_DIR="\$BASE_DIR/open/build/linux/syzkaller"

echo "=== Building Syzkaller-Compatible Kernel ==="
echo "Source: \$SRC_DIR"
echo "Build: \$BUILD_DIR"
echo

# Create build directory
mkdir -p "\$BUILD_DIR"

# Configure kernel with Syzkaller requirements
echo "Configuring kernel..."
make -C "\$SRC_DIR" O="\$BUILD_DIR" defconfig

# Enable Syzkaller-required options
cat >> "\$BUILD_DIR/.config" << EOL
# Syzkaller requirements
CONFIG_KCOV=y
CONFIG_DEBUG_INFO=y
CONFIG_KASAN=y
CONFIG_KASAN_INLINE=y
CONFIG_CONFIGFS_FS=y
CONFIG_SECURITYFS=y
CONFIG_CMDLINE_BOOL=y
CONFIG_CMDLINE="console=ttyS0 root=/dev/ram0 rw"
EOL

# Reconfigure with new options
make -C "\$SRC_DIR" O="\$BUILD_DIR" olddefconfig

# Build kernel
echo "Building kernel..."
make -C "\$SRC_DIR" O="\$BUILD_DIR" -j\$(nproc)

echo "Syzkaller kernel built successfully!"
echo "Kernel: \$BUILD_DIR/arch/x86/boot/bzImage"
echo "vmlinux: \$BUILD_DIR/vmlinux"
echo
echo "To test: \$BASE_DIR/infra/scripts/syzkaller/run_qemu_syzkaller.sh --kernel \$BUILD_DIR/arch/x86/boot/bzImage"
EOF

chmod +x "$SCRIPTS_DIR/build_syzkaller_kernel.sh"

echo
echo "=== Syzkaller Setup Complete! ==="
echo
echo "Next steps:"
echo "1. Build a Syzkaller-compatible kernel:"
echo "   $SCRIPTS_DIR/build_syzkaller_kernel.sh"
echo
echo "2. Boot kernel with Syzkaller support:"
echo "   $SCRIPTS_DIR/run_qemu_syzkaller.sh"
echo
echo "3. In guest VM, mount shared directory:"
echo "   mkdir -p /mnt/host"
echo "   mount -t 9p -o trans=virtio hostshare /mnt/host"
echo
echo "4. Run Syzkaller:"
echo "   $SCRIPTS_DIR/run_syzkaller.sh"
echo
echo "Binaries are available at: $SHARED_DIR/bin/"
echo "Configuration: $SCRIPTS_DIR/syzkaller_manager.cfg"
