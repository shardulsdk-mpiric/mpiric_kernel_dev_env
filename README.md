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
/mnt/dev_ext_4tb/                    # Root (assumes external disk mount)
├── open/                           # Main collaborative development area
│   ├── src/kernel/linux/          # Official Linux kernel source (git)
│   ├── build/linux/<profile>/     # Out-of-tree kernel builds (bzImage, modules)
│   ├── vm/linux/                  # QEMU runtime assets (initramfs, configs)
│   │   └── docs/linux/            # QEMU environment documentation
│   └── logs/qemu/                 # QEMU boot logs and test results
├── infra/                         # Infrastructure and automation scripts
│   └── scripts/qemu_linux/        # QEMU kernel testing scripts
├── shared/                        # Cross-domain shared resources
├── main_pc_data/                  # Local machine-specific data
├── personal/                      # Personal experiments and notes
├── TODO.md                        # Development roadmap and task tracking
└── README.md                      # This file
```

## 🚀 Quick Start

### Prerequisites

- Ubuntu 22.04+ (x86_64 host)
- External disk mounted at `/mnt/dev_ext_4tb`
- Basic development tools (git, make, etc.)

### Initial Setup

1. **Clone and setup the environment:**
   ```bash
   # Ensure you're in the correct directory
   cd /mnt/dev_ext_4tb

   # Run the one-time setup script
   ./open/vm/setup_qemu_for_local_kernel.sh
   ```

2. **Get the Linux kernel source:**
   ```bash
   cd open/src/kernel
   git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
   cd linux
   # Optional: checkout a specific version or branch
   ```

3. **Build your first kernel:**
   ```bash
   # Configure (out-of-tree build)
   make O=/mnt/dev_ext_4tb/open/build/linux/mainline defconfig

   # Build
   make O=/mnt/dev_ext_4tb/open/build/linux/mainline -j$(nproc)
   ```

4. **Test the kernel:**
   ```bash
   # Boot with QEMU
   /mnt/dev_ext_4tb/infra/scripts/qemu_linux/run_qemu_kernel.sh

   # Connect via SSH (in another terminal)
   ssh -p 2222 root@localhost
   ```

## 🔧 Core Workflows

### Kernel Development Cycle

```bash
# 1. Make kernel changes in source
cd open/src/kernel/linux

# 2. Build out-of-tree
make O=/mnt/dev_ext_4tb/open/build/linux/mainline -j$(nproc)

# 3. Test with QEMU
/mnt/dev_ext_4tb/infra/scripts/qemu_linux/run_qemu_kernel.sh

# 4. Iterate: modify → build → test
```

### Bug Reproduction with Syzkaller

```bash
# 1. Setup Syzkaller environment
/mnt/dev_ext_4tb/infra/scripts/syzkaller/setup_syzkaller.sh

# 2. Build Syzkaller-compatible kernel
/mnt/dev_ext_4tb/infra/scripts/syzkaller/build_syzkaller_kernel.sh

# 3. Boot with Syzkaller support
/mnt/dev_ext_4tb/infra/scripts/syzkaller/run_qemu_syzkaller.sh

# 4. Start fuzzing
/mnt/dev_ext_4tb/infra/scripts/syzkaller/run_syzkaller.sh

# In guest VM, Syzkaller binaries are auto-mounted at /mnt/host/syzkaller/bin/
```

## 📚 Documentation

- **[QEMU Environment Guide](open/vm/docs/linux/README.md)**: Detailed QEMU setup and usage
- **[Setup Instructions](open/vm/docs/linux/setup_qemu_for_local_kernel.md)**: Step-by-step setup guide
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

### Syzkaller Integration (Planned)
- **Automated fuzzing**: Bug reproduction and validation
- **Test case management**: Organized test corpus
- **Result analysis**: Automated crash analysis and reporting

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
The environment assumes an external disk mounted at `/mnt/dev_ext_4tb`. If using a different mount point, scripts will need adjustment.

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