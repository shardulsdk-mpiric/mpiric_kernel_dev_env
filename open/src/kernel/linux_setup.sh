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

# Recomended direcory layout for kernel work:
#  Source: /mnt/<your_disk_name>/open/src/kernel/linux
#  Build outputs: /mnt/<your_disk_name>/open/build/linux (out-of-tree)
#  Artifacts/logs: /mnt/<your_disk_name>/open/logs/linux

# Create them:
mkdir -p /mnt/dev_ext_4tb/open/src/kernel
mkdir -p /mnt/dev_ext_4tb/open/build/kernel/linux
mkdir -p /mnt/dev_ext_4tb/open/logs/kernel/linux

# 2) Clone official Linux mainline (the “right” way)

# From inside /mnt/dev_ext_4tb/open/src/kernel/:
cd /mnt/dev_ext_4tb/open/src/kernel/
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux

# This gives you Linus’ tree (master) which is what most people mean by “official mainline”.
# Optional (but useful) remotes for upstreaming workflow:
git remote add stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
git remote add next https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
git fetch --all --tags

# 3) Set up git identity for upstreaming (Mpiric email)
# Set identity only for this repo (safer than global):
git config --local user.name "Shardul Bankar"
git config --local user.email "shardul.b@mpiricsoftware.com"

# For kernel work, also set:
# git config format.subjectPrefix "PATCH"
git config --local sendemail.confirm always
# git config sendemail.chainreplyto false

# Configure git send-email
# You have two common choices:

# Option A (recommended): Use your email provider SMTP (works everywhere)
# Example template:
# git config sendemail.smtpServer smtp.gmail.com
# My old config:
git config --local sendemail.smtpServer smtp.zoho.in
# git config sendemail.smtpServerPort 587
# My old config:
git config --local sendemail.smtpServerPort 465
# git config sendemail.smtpEncryption tls
# My old config:
git config --local sendemail.smtpEncryption ssl
git config --local sendemail.smtpUser "shardul.b@mpiricsoftware.com"

# Then you’ll send with:
# git send-email --to <maintainer@...> 0001-your-patch.patch

# (If Mpiric email is Google Workspace / Gmail-backed, this is typical. If it’s something else, the SMTP host/port changes.)

# Option B: Use msmtp (more robust long-term)
# Setup ~/.msmtprc that supports multiple identities (personal + mpiric)

# 4) Create a clean build workflow (out-of-tree build in your open/build)
# First-time build setup (x86_64)
# From the linux source dir:

export KSRCDIR=/mnt/dev_ext_4tb/open/src/kernel/linux
export KBUILDDIR=/mnt/dev_ext_4tb/open/build/kernel/linux/mainline
mkdir -p "$KBUILDDIR"

make -C "$KSRCDIR" O="$KBUILDDIR" defconfig
make -C "$KSRCDIR" O="$KBUILDDIR" -j"$(nproc)"

# This keeps:

# 	git tree clean
# 	multiple build dirs possible (debug vs release, clang vs gcc, etc.)

# Common variants you’ll likely want:
# Debug-ish config:
# make -C "$KSRCDIR" O="$KBUILDDIR" menuconfig
# enable: CONFIG_DEBUG_INFO, CONFIG_KASAN, etc (as needed)
# make -C "$KSRCDIR" O="$KBUILDDIR" -j"$(nproc)"

# If you want a “syz-ready” build profile later, we’ll create:
# /mnt/dev_ext_4tb/open/build/linux/syzkaller/ with the right configs.

# 5) Branching model for regular work (simple + clean)

# Inside the linux repo:
git checkout master
git pull --ff-only
git checkout -b mpiric/dev

# When you want many topic branches without re-cloning, consider git worktree (very nice for kernel dev):
# cd /mnt/dev_ext_4tb/open/src/kernel/linux
# git worktree add /mnt/dev_ext_4tb/open/src/kernel/linux-wt/topic-myfeature mpiric/topic-myfeature
# Each worktree can point to a different build dir.


