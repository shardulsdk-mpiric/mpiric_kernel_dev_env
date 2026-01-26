Linux Kernel QEMU Setup Guide
===============================

This setup focuses on a BusyBox-based initramfs approach for kernel development and testing.

Why Initramfs over Disk Image?
------------------------------

For kernel development, initramfs is superior because:

- It resides in RAM, making it incredibly fast to boot
- It requires no partition management or loop-mounting
- You can easily swap the bzImage without worrying about mounting a filesystem
- It is a single file, making it highly portable

Setup Process
=============

The setup is now streamlined. Run the setup script once:

    ./open/vm/setup_qemu_for_local_kernel.sh

This script will:
- Install required Ubuntu packages (qemu, build tools, busybox-static)
- Create the necessary directory structure
- Build the initial initramfs using the committed make_initramfs.sh script

**Important:** The automation scripts are committed separately in `infra/scripts/qemu_linux/` and will not be overwritten by re-running setup.

About Static BusyBox
--------------------

For the initramfs approach, static BusyBox is required. Dynamic linking fails because the initramfs doesn't contain the dynamic loader (ld-linux-x86-64.so.2) or libc libraries.

Kernel Building (Out-of-Tree)
=============================

Run this from your kernel source directory:

    # 1. Configure (using relative paths from repo root)
    make O=../../build/linux/mainline defconfig

    # 2. Optional: Apply custom configs
    # Use the apply_configs.sh script to apply configs from config files:
    ../../tools/scripts/linux/apply_configs.sh \
        --build-dir ../../build/linux/mainline
    
    # Or let it auto-detect the latest build directory:
    ../../tools/scripts/linux/apply_configs.sh
    
    # Place config files in: open/src/kernel/tools/configs/to_load/
    # See README.md for detailed usage and Syzbot config support.

    # 3. Resolve dependencies (after applying configs)
    make O=../../build/linux/mainline olddefconfig

    # 4. Optional: Enable KVM/Virtio flags for better QEMU performance
    # Edit .config or use scripts/config

    # 5. Build
    make O=../../build/linux/mainline -j$(nproc)

The kernel artifact will be at:
`open/build/linux/mainline/arch/x86/boot/bzImage`

Testing Workflow
================

1. **Build your kernel** (as above)

2. **Boot with QEMU:**
   ```bash
   ./infra/scripts/qemu_linux/run_qemu_kernel.sh
   ```

3. **Connect via SSH** (when VM is running):
   ```bash
   ssh -p 2222 root@localhost
   ```

Key Features
============

- **No GUI:** Uses -nographic and serial console. Exit QEMU with Ctrl+A then X
- **Idempotent:** Scripts are safe to re-run
- **Separated concerns:** Source, build, and runtime assets are in distinct locations
- **Committed scripts:** Automation scripts are version-controlled, not generated
- **SSH access:** Built-in SSH forwarding for remote access to test environment

Script Locations
================

- Setup script: `open/vm/setup_qemu_for_local_kernel.sh`
- Initramfs builder: `infra/scripts/qemu_linux/make_initramfs.sh`
- QEMU launcher: `infra/scripts/qemu_linux/run_qemu_kernel.sh`
- Config manager: `open/src/kernel/tools/scripts/linux/apply_configs.sh`
- Documentation: `open/vm/docs/linux/README.md`