#!/bin/bash
# Update SSH key and sshd config in an existing syzkaller trixie image (no full rebuild).
# Use when SSH still fails after create_syzkaller_image.sh or when the key was replaced.
# Requires: trixie.img and trixie.id_rsa.pub in VM_SYZKALLER_DIR.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"
IMAGE_DIR="$VM_SYZKALLER_DIR"
cd "$IMAGE_DIR"

if [ ! -f "trixie.img" ] || [ ! -f "trixie.id_rsa.pub" ]; then
    echo "ERROR: Need trixie.img and trixie.id_rsa.pub in $IMAGE_DIR" >&2
    exit 1
fi

MOUNT_POINT="$(mktemp -d)"
cleanup() { sudo umount "$MOUNT_POINT" 2>/dev/null; rmdir "$MOUNT_POINT" 2>/dev/null; }
trap cleanup EXIT

echo "Updating SSH key and sshd config in trixie.img..."
sudo mount -o loop trixie.img "$MOUNT_POINT"
sudo mkdir -p "$MOUNT_POINT/root/.ssh"
KEY_LINE="$(tr -d '\r' < trixie.id_rsa.pub | head -1)"
printf '%s\n' "$KEY_LINE" | sudo tee "$MOUNT_POINT/root/.ssh/authorized_keys" > /dev/null
sudo chmod 700 "$MOUNT_POINT/root/.ssh"
sudo chmod 600 "$MOUNT_POINT/root/.ssh/authorized_keys"
sudo chown -R 0:0 "$MOUNT_POINT/root/.ssh"

sudo mkdir -p "$MOUNT_POINT/etc/ssh/sshd_config.d"
sudo tee "$MOUNT_POINT/etc/ssh/sshd_config.d/99-syzkaller.conf" > /dev/null << 'SSHDEOF'
# Syzkaller: allow root login with public key only
PermitRootLogin prohibit-password
PubkeyAuthentication yes
SSHDEOF
sudo chown 0:0 "$MOUNT_POINT/etc/ssh/sshd_config.d/99-syzkaller.conf"
sudo chmod 644 "$MOUNT_POINT/etc/ssh/sshd_config.d/99-syzkaller.conf"

sudo umount "$MOUNT_POINT"
trap - EXIT
rmdir "$MOUNT_POINT"
echo "Done. Restart the VM (or syzkaller) and try SSH again."
echo "Test: ssh -o IdentitiesOnly=yes -i $IMAGE_DIR/trixie.id_rsa -p PORT -o StrictHostKeyChecking=no root@localhost"
