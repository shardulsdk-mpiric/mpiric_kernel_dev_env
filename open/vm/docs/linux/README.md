# Linux Kernel QEMU Test Environment (Terminal-only)

This directory contains a **minimal, script-driven QEMU environment** used to boot
**locally compiled Linux kernels** for upstream testing and development.

The goal of this setup is:
- fast iteration on kernel builds
- zero GUI dependency
- reproducible, portable workflows
- minimal per-kernel setup overhead

This environment is intentionally simple and evolves incrementally as needs grow
(debugging, syzkaller, automation, etc.).

---

## Directory Layout (High-level)

This VM setup depends on the following fixed layout on the external dev disk:

/mnt/dev_ext_4tb/
├── open/
│ ├── src/
│ │ ├── kernel/linux   # Official Linux kernel source (git)
│ │ └── syzkaller/     # Syzkaller source (cloned by setup)
│ ├── build/
│ │ ├── linux/<profile>/  # Out-of-tree kernel builds (bzImage, modules)
│ │ └── syzkaller/        # Syzkaller binaries
│ ├── vm/
│ │ ├── linux/         # QEMU assets (initramfs for generic boot)
│ │ └── syzkaller/     # Debian Trixie image (trixie.img, trixie.id_rsa)
│ └── logs/qemu/
└── infra/scripts/
    ├── qemu_linux/    # Generic kernel boot (run_qemu_kernel.sh, make_initramfs.sh)
    └── syzkaller/     # Syzkaller setup and run (see setup_syzkaller.md)


**Important rule**
Kernel **source and build directories are always separate**.
QEMU scripts consume kernel artifacts from `open/build`, never from the source tree.

---

## What This Environment Is (and Is Not)

### ✔ This *is*
- A terminal-only QEMU setup (serial console / SSH)
- Optimized for repeated kernel boots
- Script-first (no manual QEMU command typing)
- Suitable for upstream validation and CI-like testing

### ✘ This is *not*
- A desktop VM
- A distro installer environment
- A GUI-managed VM (virt-manager, GNOME Boxes, etc.)

---

## Typical Workflow

1. **Build kernel (out-of-tree)**
   Kernel is built under:

/mnt/dev_ext_4tb/open/build/linux/<profile>/

2. **Boot kernel in QEMU**
infra/scripts/qemu_linux/run_qemu_kernel.sh

3. **Iterate**
- rebuild kernel
- re-run the script
- no VM reconfiguration needed

---

## Root Filesystem Strategy

Initial setup uses the **simplest viable root filesystem**, such as:
- initramfs (BusyBox-based), or
- minimal qcow2 image

Design goals:
- rootfs should *not* need rebuilding for every kernel change
- kernel should be swappable by pointing to a new `bzImage`

Details are documented inside the scripts themselves.

---

## Boot Automation

Guest boot automation (v1) is intentionally minimal:
- init scripts or systemd service inside the guest
- no external orchestration tools

Syzkaller uses a **Debian Trixie disk image** (not initramfs). See [setup_syzkaller.md](setup_syzkaller.md).

Other future extensions:
- snapshot mode, cloud-init–style hooks
- shared folders (9p / virtiofs) for ad-hoc use

---

## Logging

All QEMU output is logged under:

/mnt/dev_ext_4tb/open/logs/qemu/


Logs are kept per run to allow:
- regression comparison
- upstream testing records
- offline debugging

---

## Safety & Portability Notes

- All mounts are UUID-based.
- Scripts are idempotent and safe to re-run.
- The entire setup is portable across machines where the disk is mounted at:
/mnt/dev_ext_4tb


---

## Philosophy

> Minimal first.
> Automate early.
> Add complexity only when justified.

This environment is deliberately conservative and transparent.
Every layer added later should earn its place.

---

## Status

- [x] Disk + permissions setup
- [x] Kernel source + build layout
- [x] Minimal rootfs (BusyBox initramfs) for generic kernel boot
- [x] QEMU boot script
- [x] Boot-time automation hooks
- [x] SSH access to guest VMs
- [x] Syzkaller integration (Debian Trixie image, create-image.sh)
- [x] Comprehensive development roadmap (TODO.md)

## Documentation

- [setup_qemu_for_local_kernel.md](setup_qemu_for_local_kernel.md) — Generic QEMU + initramfs setup
- [setup_syzkaller.md](setup_syzkaller.md) — Syzkaller + Debian Trixie image setup


