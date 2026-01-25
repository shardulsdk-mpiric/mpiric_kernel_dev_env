# Syzkaller Setup Guide

This guide covers setting up Syzkaller for Linux kernel fuzzing with QEMU and a Debian Trixie disk image. The workflow follows the [official Syzkaller Ubuntu/QEMU x86-64 setup](https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md).

## Overview

- **Host**: Ubuntu 22.04+ (x86_64)
- **Guest**: Debian Trixie minimal image (created via Syzkaller's `create-image.sh`)
- **Kernel**: Out-of-tree build with KCOV, KASAN, DEBUG_INFO_DWARF4
- **QEMU**: Disk image + SSH key (no initramfs for Syzkaller)

## Prerequisites

- Docker (for building Syzkaller with `syz-env`)
- `debootstrap`, `qemu-system-x86`, build tools (installed by setup script)

## Setup Process

Run the setup script once:

    /mnt/dev_ext_4tb/infra/scripts/syzkaller/setup_syzkaller.sh

This will:

1. Install dependencies (Go, debootstrap, QEMU, etc.)
2. Clone/update Syzkaller source
3. Build Syzkaller via `syz-env` (Docker)
4. Create Debian Trixie image (`open/vm/syzkaller/trixie.img`, `trixie.id_rsa`)
5. Prepare shared workdir/corpus/crashes directories

**The automation scripts are committed in `infra/scripts/syzkaller/` and are not overwritten.**

## Kernel Build

Build a Syzkaller-compatible kernel (defconfig + kvm_guest.config, KCOV, KASAN, etc.):

    /mnt/dev_ext_4tb/infra/scripts/syzkaller/build_syzkaller_kernel.sh

Output: `open/build/linux/syzkaller/arch/x86/boot/bzImage`, `vmlinux`

## Booting QEMU

    /mnt/dev_ext_4tb/infra/scripts/syzkaller/run_qemu_syzkaller.sh

Options: `--kernel`, `--image`, `--ssh-port` (default 10021).

**Shared directory:** The host dir `/mnt/dev_ext_4tb/shared/` is always exported via 9p and auto-mounted in the guest at `/mnt/host` (on first access). No manual `mount` is needed.

SSH into the guest:

    ssh -i /mnt/dev_ext_4tb/open/vm/syzkaller/trixie.id_rsa -p 10021 -o StrictHostKeyChecking=no root@localhost

## Running Syzkaller

    /mnt/dev_ext_4tb/infra/scripts/syzkaller/run_syzkaller.sh

Manager UI: http://127.0.0.1:56741

## Manual Reproduction (syz-execprog)

To run a reproducer inside the guest:

1. Copy the reproducer file and Syzkaller Linux binaries (`linux_amd64/`) into the guest (e.g. via `scp -i ...`).
2. Use `syz-execprog` with a **valid Syzkaller program file** (`.txt` in [Syzkaller program format](https://github.com/google/syzkaller/blob/master/docs/syzlang.md)) or a corpus `.db` file.

Example (inside guest, after copying binaries and `repro.txt`):

    ./syz-execprog -executor=./syz-executor -repeat=0 repro.txt

**Note:** `parsed 0 programs` means the file is empty, not in Syzkaller format, or the wrong type. Use `.txt` with proper program format or a corpus database.

## Troubleshooting

### "shmem mmap failed" or "mkswap: error: swap area needs to be at least 40 KiB"

**Symptom:** `syz-execprog` fails with:
```
SYZFAIL: shmem mmap failed
size=4194304 (errno 22: Invalid argument)
mkswap: error: swap area needs to be at least 40 KiB
```

**Cause:** The minimal Debian image doesn't have swap configured. `syz-executor` requires swap support for syscalls like `swapon`, `mkswap`, and shared memory operations.

**Solution:** The image created by `create_syzkaller_image.sh` automatically includes a 64MB swap file (`/swapfile`) that is formatted and enabled at boot via a systemd service. If you're using an older image created before this fix:

```bash
# Inside the guest VM:
fallocate -l 64M /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

Or recreate the image: `create_syzkaller_image.sh` (swap is now included automatically).

### "sudo: unable to resolve host syzkaller"

**Symptom:** `sudo` shows a warning about hostname resolution.

**Solution:** Add hostname to `/etc/hosts`:
```bash
echo "127.0.0.1 syzkaller" >> /etc/hosts
```

This is cosmetic and doesn't affect functionality.

### Executing binaries from `/mnt/host` (9p mount)

If you encounter `ETXTBSY` or other filesystem errors when running binaries directly from the 9p-mounted `/mnt/host`, copy them to local disk first:

```bash
cp /mnt/host/syzkaller/bin/linux_amd64/* /tmp/
cd /tmp
./syz-execprog -executor=./syz-executor ...
```

## Script Locations

| Script | Purpose |
|--------|---------|
| `infra/scripts/syzkaller/setup_syzkaller.sh` | One-time setup |
| `infra/scripts/syzkaller/create_syzkaller_image.sh` | Build Debian Trixie image |
| `infra/scripts/syzkaller/build_syzkaller_kernel.sh` | Build Syzkaller kernel |
| `infra/scripts/syzkaller/run_qemu_syzkaller.sh` | Boot QEMU with image |
| `infra/scripts/syzkaller/run_syzkaller.sh` | Run syzkaller manager |
| `infra/scripts/syzkaller/syzkaller_manager.cfg` | Manager config |

## Image vs Initramfs

For **Syzkaller**, we use the **Debian Trixie disk image** (not BusyBox initramfs) because:

- Syzkaller expects `sshd`, `strace`, proper `/sys` layout (debugfs, configfs, etc.)
- Official tooling (`create-image.sh`) produces a compatible rootfs
- SSH key authentication is required for the manager

The minimal initramfs (`make_initramfs.sh`) remains for **generic kernel boot testing** only.

## References

- [Syzkaller Ubuntu + QEMU + x86-64 kernel](https://github.com/google/syzkaller/blob/master/docs/linux/setup_ubuntu-host_qemu-vm_x86-64-kernel.md)
- [Syzkaller create-image.sh](https://github.com/google/syzkaller/blob/master/tools/create-image.sh)
- [Kernel configs for Syzkaller](https://github.com/google/syzkaller/blob/master/docs/linux/kernel_configs.md)
