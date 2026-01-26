#!/bin/bash
#
# Linux Kernel Setup Script
#
# This script sets up a Linux kernel development environment including
# dependencies, directory structure, kernel source, and git configuration.
#
# Usage: ./linux_setup.sh
#        Or source it and run commands manually

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up to workspace root: open/src/kernel/ -> open/src/ -> open/ -> workspace root
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$WORKSPACE_ROOT/infra/scripts/config.sh"

echo "=== Linux Kernel Development Setup ==="
echo "Workspace root: $KERNEL_DEV_ENV_ROOT"
echo

# 1) Install dependencies
echo "1. Installing dependencies..."
sudo apt-get update
sudo apt-get install -y \
  git git-email \
  build-essential bc bison flex \
  libssl-dev libelf-dev dwarves \
  pahole \
  libncurses-dev \
  ccache \
  python3 rsync \
  fakeroot \
  qemu-system-x86 qemu-utils \
  pkg-config

# Optional but nice:
sudo apt-get install -y ripgrep bear

# 2) Create directory structure
echo "2. Creating directory structure..."
mkdir -p "$KERNEL_SRC_DIR"
mkdir -p "$KERNEL_BUILD_DIR"
mkdir -p "$OPEN_DIR/logs/kernel/linux"

# 3) Clone official Linux mainline (the "right" way)
echo "3. Setting up kernel source..."
if [ ! -d "$KERNEL_SRC_DIR/.git" ]; then
    echo "Cloning Linux kernel source..."
    cd "$(dirname "$KERNEL_SRC_DIR")"
    git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git "$(basename "$KERNEL_SRC_DIR")"
    cd "$KERNEL_SRC_DIR"
else
    echo "Kernel source already exists at $KERNEL_SRC_DIR"
    cd "$KERNEL_SRC_DIR"
fi

# This gives you Linus' tree (master) which is what most people mean by "official mainline".
# Optional (but useful) remotes for upstreaming workflow:
if ! git remote | grep -q "^stable$"; then
    git remote add stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
fi
if ! git remote | grep -q "^next$"; then
    git remote add next https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
fi
git fetch --all --tags

# 4) Set up git identity for upstreaming
# NOTE: Update these with your own name and email
# Set identity only for this repo (safer than global):
GIT_USER_NAME="${GIT_USER_NAME:-Your Name}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-your.email@example.com}"

echo "4. Configuring git identity..."
echo "  Name: $GIT_USER_NAME"
echo "  Email: $GIT_USER_EMAIL"
echo "  (Set GIT_USER_NAME and GIT_USER_EMAIL environment variables to customize)"
git config --local user.name "$GIT_USER_NAME"
git config --local user.email "$GIT_USER_EMAIL"

# For kernel work, also set:
# git config format.subjectPrefix "PATCH"
git config --local sendemail.confirm always
# git config sendemail.chainreplyto false

# Configure git send-email
# You have two common choices:

# Option A (recommended): Use your email provider SMTP (works everywhere)
# Example template (uncomment and customize):
# git config --local sendemail.smtpServer smtp.gmail.com
# git config --local sendemail.smtpServerPort 587
# git config --local sendemail.smtpEncryption tls
# git config --local sendemail.smtpUser "$GIT_USER_EMAIL"

# Option B: Use msmtp (more robust long-term)
# Setup ~/.msmtprc that supports multiple identities

echo
echo "5. Git send-email configuration:"
echo "  Configure SMTP settings manually or use msmtp"
echo "  See: https://git-scm.com/docs/git-send-email"
echo

# 6) Create a clean build workflow (out-of-tree build)
echo "6. Setting up build directory..."
BUILD_PROFILE="${BUILD_PROFILE:-mainline}"
BUILD_DIR="$KERNEL_BUILD_DIR/$BUILD_PROFILE"
mkdir -p "$BUILD_DIR"

export KSRCDIR="$KERNEL_SRC_DIR"
export KBUILDDIR="$BUILD_DIR"

echo "  Source: $KSRCDIR"
echo "  Build:  $KBUILDDIR"
echo
echo "To build the kernel:"
echo "  make -C \"\$KSRCDIR\" O=\"\$KBUILDDIR\" defconfig"
echo "  make -C \"\$KSRCDIR\" O=\"\$KBUILDDIR\" -j\$(nproc)"
echo

# 7) Branching model for regular work (simple + clean)
echo "7. Git workflow setup..."
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "master" ] || [ "$CURRENT_BRANCH" = "main" ]; then
    echo "  Current branch: $CURRENT_BRANCH"
    echo "  Create a development branch with: git checkout -b <your-branch-name>"
else
    echo "  Current branch: $CURRENT_BRANCH"
fi
echo

# When you want many topic branches without re-cloning, consider git worktree (very nice for kernel dev):
# cd "$KERNEL_SRC_DIR"
# git worktree add "$KERNEL_SRC_DIR-wt/topic-myfeature" <branch-name>
# Each worktree can point to a different build dir.

echo "=== Setup Complete ==="
echo
echo "Next steps:"
echo "  1. Configure kernel: make -C \"\$KSRCDIR\" O=\"\$KBUILDDIR\" defconfig"
echo "  2. Build kernel: make -C \"\$KSRCDIR\" O=\"\$KBUILDDIR\" -j\$(nproc)"
echo "  3. Test with QEMU: $SCRIPTS_QEMU_DIR/run_qemu_kernel.sh"
echo
echo "Directory structure:"
echo "  Source: $KERNEL_SRC_DIR"
echo "  Build:  $KERNEL_BUILD_DIR"
echo "  Logs:   $OPEN_DIR/logs/kernel/linux"


