# Syzkaller scripts

Scripts for building, imaging, and running syzkaller in this kernel dev environment.

## Prerequisites and order

1. **setup_syzkaller.sh** – Build syzkaller binaries and prepare layout.
2. **create_syzkaller_image.sh** – Create Debian VM image for fuzzing.
3. **build_syzkaller_kernel.sh** – Build a kernel with syzkaller config (or use your own build and set `KBUILDDIR`).

You need a **syzkaller config file** (JSON) that points to your kernel build, image, workdir, etc. You can generate one (see below) or write your own.

## What to run when

| Goal | Script | Notes |
|------|--------|--------|
| **Long-running fuzzing** (detached, with log rotation) | **start_syzkaller_manager.sh** | Run in screen; you must pass config with `-config <path>`. Use `--cleanup` to stop. |
| **One-off or debugging** (foreground, no screen) | **run_syzkaller_foreground.sh** | Optional `--config <path>`; can auto-discover or generate a default config. |
| **Generate / choose config** | Used by **run_syzkaller_foreground.sh** | Or use the **syzkaller_common.sh** module from your own script. |

## Script summary

- **start_syzkaller_manager.sh** – Start syz-manager in a detached screen session. Logs rotate by size. Requires `-config <path>`. For long-running fuzzing.
- **run_syzkaller_foreground.sh** – Run syz-manager in the foreground (no screen). Optional `--config`; can generate or select a default config. For quick runs or debugging.
- **syzkaller_common.sh** – Shared logic (sourced by other scripts): prerequisite checks, default config generation, config discovery/selection. Not meant to be run directly.
- **setup_syzkaller.sh** – Build syzkaller and set up directories.
- **create_syzkaller_image.sh** – Create the Debian VM image (e.g. trixie.img).
- **build_syzkaller_kernel.sh** – Build kernel with syzkaller-friendly config.
- **run_qemu_syzkaller.sh** – Run QEMU with the syzkaller VM image (for manual testing or imaging).
- **update_syzkaller_image_ssh.sh** – Update only SSH key and sshd config in an existing trixie.img (no full rebuild). Use when SSH still fails after fixing the key.

## Example config

**syzkaller_manager_hfsplus.cfg** in this directory is a working example that:

- Sets **vm.cmdline** to `net.ifnames=0` so the Debian guest uses the `eth0` interface name (required for networking when using the syzkaller create-image.sh image).
- Targets the hfsplus subsystem via **experimental.focus_areas** (optional; adjust or remove if not needed).
- Uses absolute paths for `kernel_obj`, `kernel`, `image`, `sshkey`, `workdir`, `syzkaller` — **copy the file and update these paths** for your workspace and kernel build.

From repo root:

```bash
# Long-running: start manager in screen (use the example config; adjust paths in the .cfg for your setup)
./infra/scripts/syzkaller/start_syzkaller_manager.sh -config infra/scripts/syzkaller/syzkaller_manager_hfsplus.cfg

# Stop the manager
./infra/scripts/syzkaller/start_syzkaller_manager.sh --cleanup

# One-off foreground run
./infra/scripts/syzkaller/run_syzkaller_foreground.sh --config infra/scripts/syzkaller/syzkaller_manager_hfsplus.cfg
```

## Troubleshooting

- **SSH fails (exit 255) after VM boot:**
  1. **Manual test must use `IdentitiesOnly=yes`** or you get "Too many authentication failures" (the server tries only ~6 keys; your agent may offer more before the trixie key):  
     `ssh -o IdentitiesOnly=yes -i open/vm/syzkaller/trixie.id_rsa -p 10021 -o StrictHostKeyChecking=no root@localhost`  
     (Use the port from run_qemu_syzkaller.sh or from the syzkaller log.)
  2. If that still fails (e.g. "Permission denied (publickey)"): refresh the key and sshd config in the image **without a full rebuild** by running  
     **update_syzkaller_image_ssh.sh** (from repo root, with config sourced). Then restart the VM or syzkaller and try again.
  3. Or do a full image rebuild: **create_syzkaller_image.sh** (writes the current key and sshd drop-in into the image).
- **networking.service fails in guest:** Ensure your syzkaller config has **vm.cmdline** including `net.ifnames=0` so the NIC is named `eth0` and matches `/etc/network/interfaces` in the image.
