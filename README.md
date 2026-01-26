# Linux Kernel Development Environment

A comprehensive, terminal-only development environment for Linux kernel upstream work, including QEMU-based testing, Syzkaller integration, and reproducible kernel testing workflows.

## 🎯 Project Overview

This repository provides a complete environment for Linux kernel development, testing, and upstream contribution. It focuses on:

- **Upstream Kernel Development**: Building, testing, and debugging Linux kernel changes
- **Reproducible Testing**: QEMU-based kernel testing with minimal dependencies
- **Syzkaller Integration**: Automated fuzzing for bug reproduction and validation
- **Terminal-First**: No GUI dependencies, optimized for remote/server development

## 📁 Directory Structure

```
<workspace-root>/                   # Repository root (auto-detected or set via KERNEL_DEV_ENV_ROOT)
├── open/                          # Main collaborative development area
│   ├── src/kernel/linux/         # Official Linux kernel source (git)
│   │   └── tools/scripts/linux/  # Kernel development tools (apply_configs.sh)
│   │       └── configs/to_load/   # Kernel config files to apply
│   ├── build/linux/<profile>/     # Out-of-tree kernel builds (bzImage, modules)
│   ├── vm/linux/                  # QEMU runtime assets (initramfs, configs)
│   │   └── docs/linux/            # QEMU environment documentation
│   └── logs/qemu/                 # QEMU boot logs and test results
├── infra/                         # Infrastructure and automation scripts
│   └── scripts/                   # Scripts and configuration
│       ├── config.sh              # Path configuration (auto-detects workspace root)
│       ├── qemu_linux/            # QEMU kernel testing scripts
│       └── syzkaller/             # Syzkaller setup and run scripts
├── shared/                        # Cross-domain shared resources
├── TODO.md                        # Development roadmap and task tracking
└── README.md                      # This file
```

## 🚀 Quick Start

### Prerequisites

- Ubuntu 22.04+ (x86_64 host)
- Basic development tools (git, make, etc.)
- Sufficient disk space (~50GB+ for kernel builds)

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd <workspace-directory>
   ```

2. **Run the one-time setup script:**
   ```bash
   # The script auto-detects the workspace root
   ./open/vm/setup_qemu_for_local_kernel.sh
   
   # Or set workspace root explicitly (optional):
   # export KERNEL_DEV_ENV_ROOT=/path/to/workspace
   # ./open/vm/setup_qemu_for_local_kernel.sh
   ```

3. **Get the Linux kernel source:**
   ```bash
   cd open/src/kernel
   git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
   cd linux
   # Optional: checkout a specific version or branch
   ```

4. **Build your first kernel:**
   ```bash
   # Configure (out-of-tree build)
   # Scripts auto-detect workspace root, or use relative paths
   make O=../../build/linux/mainline defconfig

   # Build
   make O=../../build/linux/mainline -j$(nproc)
   ```

5. **Test the kernel:**
   ```bash
   # Boot with QEMU (auto-detects paths)
   ./infra/scripts/qemu_linux/run_qemu_kernel.sh

   # Connect via SSH (in another terminal)
   ssh -p 2222 root@localhost
   ```

## 🔧 Core Workflows

### Kernel Development Cycle

```bash
# 1. Make kernel changes in source
cd open/src/kernel/linux

# 2. Build out-of-tree (relative paths work from repo root)
make O=../../build/linux/mainline -j$(nproc)

# 3. Test with QEMU (auto-detects workspace root)
./infra/scripts/qemu_linux/run_qemu_kernel.sh

# 4. Iterate: modify → build → test
```

### Kernel Configuration Management

The environment includes a script to manage kernel configuration files across multiple build directories:

**Location:** `open/src/kernel/tools/scripts/linux/apply_configs.sh`

**Features:**
- Automatically finds the latest build directory (by modification time)
- Applies configs from `open/src/kernel/tools/configs/to_load/*`
- Supports selective Syzbot config application
- Works with out-of-tree builds

**Usage:**

```bash
# Apply configs to latest build directory (default)
./open/src/kernel/tools/scripts/linux/apply_configs.sh

# Apply configs to specific build directory
./open/src/kernel/tools/scripts/linux/apply_configs.sh \
    --build-dir open/build/linux/mainline

# Apply standard configs + selective Syzbot config
./open/src/kernel/tools/scripts/linux/apply_configs.sh \
    --syzbot-config /path/to/syzbot_reported.config
```

**Config Files:**
- Standard configs: Place `.config`-style files in `open/src/kernel/tools/configs/to_load/`
- Syzbot configs: Use `--syzbot-config` to selectively apply relevant configs (toolchain/version info is automatically skipped)

After applying configs, run `make olddefconfig` in your build directory to resolve dependencies.

### Bug Reproduction with Syzkaller

**Prerequisites:** Docker installed and running. See [setup_syzkaller.md](open/vm/docs/linux/setup_syzkaller.md).

```bash
# 1. Setup Syzkaller + Debian Trixie image (requires Docker)
sudo systemctl start docker  # if not running
./infra/scripts/syzkaller/setup_syzkaller.sh

# 2. Build Syzkaller-compatible kernel
./infra/scripts/syzkaller/build_syzkaller_kernel.sh

# 3. Boot QEMU with Debian image
./infra/scripts/syzkaller/run_qemu_syzkaller.sh

# 4. Run syzkaller manager (separate terminal)
./infra/scripts/syzkaller/run_syzkaller.sh

# SSH to guest: ssh -i open/vm/syzkaller/trixie.id_rsa -p 10021 root@localhost
```

## 📚 Documentation

- **[QEMU Environment Guide](open/vm/docs/linux/README.md)**: Detailed QEMU setup and usage
- **[QEMU + Initramfs Setup](open/vm/docs/linux/setup_qemu_for_local_kernel.md)**: Generic kernel boot
- **[Syzkaller Setup](open/vm/docs/linux/setup_syzkaller.md)**: Syzkaller + Debian Trixie image
- **[Development Roadmap](TODO.md)**: Planned features and improvements

## 🛠️ Key Components

### QEMU Testing Environment
- **Terminal-only**: No GUI dependencies
- **Fast iteration**: RAM-based initramfs for quick reboots
- **SSH access**: Remote testing capabilities
- **Logging**: Comprehensive test result tracking

### Build System
- **Out-of-tree builds**: Clean separation of source and build artifacts
- **Multiple profiles**: Support for different kernel configurations
- **Reproducible**: Consistent build environments

### Syzkaller Integration
- **Debian Trixie image**: Syzkaller `create-image.sh`; disk image + SSH key
- **Automated fuzzing**: syz-manager, syz-fuzzer, syz-executor
- **Manual repro**: syz-execprog in guest (see [setup_syzkaller.md](open/vm/docs/linux/setup_syzkaller.md))

## 🤝 Development Philosophy

### Minimal First
Start with the simplest working solution and add complexity only when justified.

### Terminal-First
All workflows should work in terminal environments, enabling remote development and CI/CD integration.

### Reproducible
Every setup and workflow should be scriptable and version-controlled.

### Collaborative
Environment designed for team development with clear separation of concerns.

## 🔄 Current Status

- [x] Basic QEMU kernel testing environment
- [x] Out-of-tree kernel build support
- [x] SSH access to test VMs
- [x] Comprehensive logging
- [x] Script-based automation
- [x] Syzkaller integration with shared directory
- [ ] Multi-profile build support
- [ ] Enhanced debugging tools
- [ ] CI/CD integration

See [TODO.md](TODO.md) for detailed roadmap and planned improvements.

## 📋 Requirements

### Host System
- Ubuntu 22.04 or compatible (x86_64)
- QEMU (installed by setup script)
- Linux kernel build dependencies (gcc, make, etc.)
- External storage with sufficient space (~50GB+ for kernel builds)

### Storage Layout
The environment auto-detects the workspace root from the repository location. You can override this by setting the `KERNEL_DEV_ENV_ROOT` environment variable. All paths are relative to the workspace root.

## 🆘 Troubleshooting

### Common Issues

**QEMU won't start:**
- Ensure KVM is available: `lsmod | grep kvm`
- Check kernel build: `file open/build/linux/mainline/arch/x86/boot/bzImage`

**SSH connection fails:**
- Verify VM is running
- Check QEMU network configuration
- Ensure SSH service is running in guest

**Build failures:**
- Verify all build dependencies are installed
- Check kernel config for required options
- Ensure sufficient disk space

### Getting Help

1. Check the logs: `open/logs/qemu/`
2. Review detailed documentation in `open/vm/docs/linux/`
3. Check [TODO.md](TODO.md) for known limitations

## 🤝 Contributing

This environment is designed for collaborative kernel upstream work. Contributions welcome for:

- Bug fixes and improvements
- New features and tools
- Documentation enhancements
- Syzkaller integration work

See [TODO.md](TODO.md) for contribution opportunities and development priorities.

## 📄 License

This repository contains scripts and configuration for Linux kernel development. The Linux kernel itself is licensed under GPL-2.0.

---

**Maintained by:** Linux Kernel Development Team
**Last updated:** January 2026