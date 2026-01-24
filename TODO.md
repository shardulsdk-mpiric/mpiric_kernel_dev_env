# Linux Kernel Development Environment - TODO

This document outlines planned improvements and features for the Linux kernel development environment. The environment focuses on upstream kernel testing, debugging, and reproduction of Syzbot-reported issues using QEMU and Syzkaller.

## Project Overview

This is a minimal, terminal-only development environment for Linux kernel upstream work. Key components:
- Out-of-tree kernel builds
- QEMU-based testing with initramfs
- Syzkaller integration for fuzzing
- Script-driven workflows for reproducibility

## Current Status

- [x] Basic directory structure and layout
- [x] Initial QEMU setup with initramfs (BusyBox-based)
- [x] Kernel build integration (out-of-tree)
- [x] SSH access to guest VMs
- [x] Basic logging and automation hooks

## High Priority Tasks

### 1. Path Genericization and Portability

**Goal:** Make the environment portable across different systems, not tied to `/mnt/dev_ext_4tb`.

**Tasks:**
- [ ] Implement environment variable-based configuration system
- [ ] Add `setup.sh` script to detect and configure paths automatically
- [ ] Replace hardcoded `/mnt/dev_ext_4tb` with configurable base directory
- [ ] Add validation for required directories and permissions
- [ ] Document installation process for new machines
- [ ] Support relative paths for development on different filesystems

**Rationale:** Current setup is tightly coupled to specific mount point, limiting portability.

### 2. Syzkaller Integration

**Goal:** Enable Syzkaller-based fuzzing for reproducing and testing kernel issues.

**Tasks:**
- [ ] Set up Syzkaller source repository in `open/src/syzkaller/`
- [ ] Create build script for Syzkaller binaries (`infra/scripts/syzkaller/build_syzkaller.sh`)
- [ ] Store built binaries in standardized location (`open/build/syzkaller/`)
- [ ] Integrate Syzkaller binaries into QEMU initramfs or guest filesystem
- [ ] Add syzkaller-specific QEMU profiles and configurations
- [ ] Create wrapper scripts for common Syzkaller workflows (reproduce, test, etc.)
- [ ] Document Syzkaller setup and usage patterns

**Rationale:** Syzkaller is essential for reproducing Syzbot-reported issues.

### 3. Shared Directory and Host-Guest Integration

**Goal:** Enable seamless file sharing between host and guest systems.

**Tasks:**
- [ ] Implement 9p/virtiofs shared directory mounting
- [ ] Configure shared directory at standardized location (`shared/` in workspace root)
- [ ] Add shared directory to QEMU command line
- [ ] Create scripts to mount shared directory in guest automatically
- [ ] Ensure shared directory permissions work for both host and guest
- [ ] Add shared directory to initramfs or persistent rootfs

**Rationale:** Essential for transferring test cases, logs, and artifacts between host/guest.

### 4. SSH Connection Management

**Goal:** Provide easy, scriptable SSH access to running VMs.

**Tasks:**
- [ ] Create `ssh_guest.sh` script for automatic SSH connection
- [ ] Implement SSH key-based authentication setup
- [ ] Add SSH configuration management (known_hosts, config files)
- [ ] Support multiple concurrent VMs with different SSH ports
- [ ] Add connection retry logic and error handling
- [ ] Document SSH setup and troubleshooting

**Rationale:** Current SSH setup requires manual port forwarding configuration.

## Medium Priority Tasks

### 5. Configuration Management

**Goal:** Centralize and simplify configuration options.

**Tasks:**
- [ ] Create `config.env` or `config.sh` file for environment variables
- [ ] Move all configurable options (kernel builds, memory, CPUs, etc.) to config file
- [ ] Add config validation and defaults
- [ ] Support per-profile configurations (debug, mainline, syzkaller, etc.)
- [ ] Create `config.sh --list` to show current configuration
- [ ] Add config backup/restore functionality

**Rationale:** Currently scattered configuration makes customization difficult.

### 6. Build Profile Management

**Goal:** Support multiple kernel build configurations easily.

**Tasks:**
- [ ] Extend build scripts to support multiple profiles (mainline, debug, syzkaller)
- [ ] Add profile-specific kernel configurations
- [ ] Create profile switching commands
- [ ] Add profile validation and dependency checking
- [ ] Document each profile's purpose and use cases

**Rationale:** Different testing scenarios require different kernel configurations.

### 7. Enhanced Logging and Debugging

**Goal:** Improve observability and debugging capabilities.

**Tasks:**
- [ ] Implement structured logging with timestamps and log levels
- [ ] Add kernel panic/crash detection in logs
- [ ] Create log analysis tools for common patterns
- [ ] Add performance metrics collection (boot time, memory usage)
- [ ] Implement log rotation and cleanup
- [ ] Add log export functionality for bug reports

**Rationale:** Better debugging is crucial for kernel development.

### 8. Root Filesystem Improvements

**Goal:** Move beyond initramfs to more capable root filesystems.

**Tasks:**
- [ ] Implement persistent qcow2-based root filesystem
- [ ] Add package management support (apt, dpkg) to guest
- [ ] Create base image building pipeline
- [ ] Add snapshot/restore functionality
- [ ] Support multiple rootfs profiles (minimal, debug, full)
- [ ] Document rootfs creation and customization

**Rationale:** Initramfs is too limited for complex testing scenarios.

## Low Priority Tasks

### 9. CI/CD Integration

**Goal:** Enable automated testing pipelines.

**Tasks:**
- [ ] Create GitHub Actions workflows for basic validation
- [ ] Add kernel build verification scripts
- [ ] Implement automated test execution
- [ ] Add result reporting and notifications
- [ ] Support multiple kernel versions in CI

**Rationale:** Automated validation reduces manual testing burden.

### 10. Documentation Improvements

**Goal:** Comprehensive documentation for contributors.

**Tasks:**
- [ ] Create detailed setup guide for new contributors
- [ ] Add troubleshooting section for common issues
- [ ] Document all scripts and their parameters
- [ ] Create video tutorials for complex setups
- [ ] Add FAQ and known issues section

**Rationale:** Good documentation is essential for collaborative development.

### 11. Performance Optimization

**Goal:** Improve boot times and resource usage.

**Tasks:**
- [ ] Optimize initramfs size and boot time
- [ ] Add QEMU performance tuning options
- [ ] Implement kernel precompilation caching
- [ ] Add parallel build support
- [ ] Profile and optimize common workflows

**Rationale:** Faster iteration improves development productivity.

### 12. Security Hardening

**Goal:** Ensure secure development practices.

**Tasks:**
- [ ] Implement proper permission management
- [ ] Add input validation for all scripts
- [ ] Create secure SSH key management
- [ ] Add audit logging for sensitive operations
- [ ] Implement safe defaults for network configurations

**Rationale:** Kernel development involves security-critical code.

## Task Dependencies

- Path genericization (Task 1) should be completed before most other tasks
- Syzkaller integration (Task 2) depends on shared directories (Task 3)
- Configuration management (Task 5) affects most other tasks
- Root filesystem improvements (Task 8) enable advanced features

## Contributing

When implementing tasks:
1. Update this TODO file with progress and completion status
2. Follow existing code style and conventions
3. Add appropriate documentation for new features
4. Test changes on multiple kernel versions when applicable
5. Ensure backward compatibility where possible

## Testing Strategy

- Manual testing for basic functionality
- Automated tests for script correctness
- Kernel boot testing across different configurations
- Integration testing with Syzkaller workflows
- Performance regression testing

---

*Last updated: January 2026*
*Maintainer: Development Team*