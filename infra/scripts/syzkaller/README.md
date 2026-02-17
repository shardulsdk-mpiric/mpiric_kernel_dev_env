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

- **SSH fails (exit 255) after VM boot:** The guest must accept the key in `sshkey` (e.g. `trixie.id_rsa`). If you recreated the key or the image was built elsewhere, re-run **create_syzkaller_image.sh** so the image’s `root/.ssh/authorized_keys` is updated to match the current `trixie.id_rsa.pub`. You can also verify from the host: `ssh -i open/vm/syzkaller/trixie.id_rsa -p PORT -o StrictHostKeyChecking=no -vv root@localhost` (use the port syzkaller prints in the log).
- **networking.service fails in guest:** Ensure your syzkaller config has **vm.cmdline** including `net.ifnames=0` so the NIC is named `eth0` and matches `/etc/network/interfaces` in the image.
