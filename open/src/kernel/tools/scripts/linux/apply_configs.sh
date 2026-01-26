#!/bin/bash
#
# Apply Kernel Configuration Script
#
# Applies kernel configuration files to a build directory's .config file.
# Supports standard config files and Syzbot-reported configs (selective application).
#
# Usage:
#   ./apply_configs.sh [--build_dir PATH] [--syzbot-config PATH]
#
# Copyright (C) 2026 Linux Kernel Development Team
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up to workspace root: open/src/kernel/tools/scripts/linux/ -> scripts/ -> tools/ -> kernel/ -> src/ -> open/ -> workspace root
# That's 6 levels up
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../../../../" && pwd)"
# Validate workspace root
if [ ! -d "$WORKSPACE_ROOT/infra" ] || [ ! -d "$WORKSPACE_ROOT/open" ]; then
    echo "Error: Could not detect workspace root from script location." >&2
    echo "Set KERNEL_DEV_ENV_ROOT environment variable or run from workspace root." >&2
    exit 1
fi
source "$WORKSPACE_ROOT/infra/scripts/config.sh"

# Configuration (using config system)
KERNEL_SRC="$KERNEL_SRC_DIR"
BUILD_BASE="$KERNEL_BUILD_DIR"
CONFIGS_DIR="$OPEN_DIR/src/kernel/tools/configs/to_load"

# Helper logging function
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*" >&2
}

log_error() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ERROR: $*" >&2
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Apply kernel configuration files to a build directory's .config.

OPTIONS:
    --build-dir PATH     Build directory to update
                        (default: KBUILDDIR env var, or latest in $BUILD_BASE)
    --syzbot-config PATH Apply specific configs from a Syzbot-reported config file
    --help              Show this help message

ENVIRONMENT:
    KBUILDDIR           If set, used as default build directory
                        (overridden by --build-dir argument)
                        (auto-set by config.sh with timestamped prefix)

EXAMPLES:
    # Apply configs to latest build directory
    $0

    # Apply configs using KBUILDDIR environment variable (from config.sh)
    source infra/scripts/config.sh
    $0

    # Apply configs to specific build directory (overrides KBUILDDIR)
    $0 --build-dir $BUILD_BASE/2026_01_25_142350_mainline

    # Apply configs and merge specific Syzbot config
    $0 --syzbot-config /path/to/syzbot.config

EOF
}

# Find the latest build directory
find_latest_build_dir() {
    local latest=""
    local latest_mtime=0
    
    # Find all build directories (two levels deep: profile/build_name)
    while IFS= read -r dir; do
        if [ -f "$dir/.config" ]; then
            local mtime=$(stat -c %Y "$dir/.config" 2>/dev/null || echo 0)
            if [ "$mtime" -gt "$latest_mtime" ]; then
                latest_mtime=$mtime
                latest="$dir"
            fi
        fi
    done < <(find "$BUILD_BASE" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)
    
    if [ -n "$latest" ]; then
        echo "$latest"
    else
        log_error "No build directories found in $BUILD_BASE"
        return 1
    fi
}

# Apply a single config option using scripts/config
apply_config_option() {
    local config="$1"
    local value="$2"
    local config_file="$3"
    
    case "$value" in
        "y")
            "$KERNEL_SRC/scripts/config" --file "$config_file" --enable "$config" || true
            ;;
        "m")
            "$KERNEL_SRC/scripts/config" --file "$config_file" --module "$config" || true
            ;;
        "n")
            "$KERNEL_SRC/scripts/config" --file "$config_file" --disable "$config" || true
            ;;
        *)
            if [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
                # Numeric value (decimal or hexadecimal)
                "$KERNEL_SRC/scripts/config" --file "$config_file" --set-val "$config" "$value" || true
            elif [[ "$value" =~ ^\".*\"$ ]]; then
                # String value (remove quotes)
                local val="${value:1:-1}"
                "$KERNEL_SRC/scripts/config" --file "$config_file" --set-str "$config" "$val" || true
            else
                log "Warning: Unknown value format '$value' for $config, skipping"
            fi
            ;;
    esac
}

# Apply standard kernel config file (applies all configs)
apply_standard_config() {
    local config_file="$1"
    local build_dir="$2"
    local config_path="$build_dir/.config"
    
    if [ ! -f "$config_file" ]; then
        log_error "Config file not found: $config_file"
        return 1
    fi
    
    log "Applying standard config file: $config_file"
    local count=0
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Extract config name and value (format: CONFIG_FOO=value or CONFIG_FOO="value")
        if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
            local config="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Skip toolchain/version configs that shouldn't be applied
            if [[ "$config" =~ ^CONFIG_(CC_|GCC_|CLANG_|AS_|LD_|LLD_|RUSTC_|PAHOLE_|CC_HAS_|TOOLS_) ]]; then
                continue
            fi
            
            apply_config_option "$config" "$value" "$config_path"
            ((count++)) || true
        fi
    done < "$config_file"
    
    log "Applied $count config options from $config_file"
}

# Apply Syzbot config file (selective - only relevant configs)
# Syzbot configs are full kernel configs with toolchain info, so we only
# extract configs that are relevant for reproducing the issue
apply_syzbot_config() {
    local syzbot_file="$1"
    local build_dir="$2"
    local config_path="$build_dir/.config"
    
    if [ ! -f "$syzbot_file" ]; then
        log_error "Syzbot config file not found: $syzbot_file"
        return 1
    fi
    
    log "Applying selective configs from Syzbot config: $syzbot_file"
    log "Note: Only applying relevant configs (excluding toolchain/version info)"
    
    local count=0
    local skipped=0
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
            local config="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Skip toolchain/compiler/version configs
            if [[ "$config" =~ ^CONFIG_(CC_|GCC_|CLANG_|AS_|LD_|LLD_|RUSTC_|PAHOLE_|CC_HAS_|TOOLS_|BUILDTIME_) ]]; then
                ((skipped++)) || true
                continue
            fi
            
            # Skip LOCALVERSION and other build-specific configs
            if [[ "$config" =~ ^CONFIG_(LOCALVERSION|INITRAMFS_) ]]; then
                ((skipped++)) || true
                continue
            fi
            
            # Apply the config
            apply_config_option "$config" "$value" "$config_path"
            ((count++)) || true
        fi
    done < "$syzbot_file"
    
    log "Applied $count config options from Syzbot config (skipped $skipped toolchain/build-specific configs)"
}

# Main execution
main() {
    local build_dir=""
    local syzbot_config=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build-dir|--build_dir)
                build_dir="$2"
                shift 2
                ;;
            --syzbot-config|--syzbot_config)
                syzbot_config="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Determine build directory
    # Priority: 1) --build-dir argument, 2) KBUILDDIR env var, 3) latest build dir
    if [ -z "$build_dir" ]; then
        if [ -n "${KBUILDDIR:-}" ]; then
            build_dir="$KBUILDDIR"
            log "Using KBUILDDIR environment variable: $build_dir"
        else
            log "Finding latest build directory..."
            build_dir=$(find_latest_build_dir)
            log "Using latest build directory: $build_dir"
        fi
    else
        log "Using --build-dir argument: $build_dir"
    fi
    
    # Validate build directory
    if [ ! -d "$build_dir" ]; then
        log_error "Build directory does not exist: $build_dir"
        exit 1
    fi
    
    # Check .config exists
    local config_file="$build_dir/.config"
    if [ ! -f "$config_file" ]; then
        log_error ".config not found in build directory: $build_dir"
        log_error "Run 'make defconfig' or similar first."
        exit 1
    fi
    
    # Check kernel source exists
    if [ ! -f "$KERNEL_SRC/scripts/config" ]; then
        log_error "Kernel scripts/config not found at $KERNEL_SRC/scripts/config"
        log_error "Ensure kernel source is available."
        exit 1
    fi
    
    log "Updating kernel configuration in: $build_dir"
    log "Config file: $config_file"
    echo
    
    # Apply standard config files from to_load directory
    if [ -d "$CONFIGS_DIR" ]; then
        local config_files=("$CONFIGS_DIR"/*)
        if [ -e "${config_files[0]}" ]; then
            log "Applying configs from $CONFIGS_DIR..."
            for config_file_path in "${config_files[@]}"; do
                if [ -f "$config_file_path" ]; then
                    apply_standard_config "$config_file_path" "$build_dir"
                fi
            done
        else
            log "No config files found in $CONFIGS_DIR (directory is empty)"
        fi
    else
        log "Configs directory not found: $CONFIGS_DIR (skipping standard configs)"
    fi
    
    # Apply Syzbot config if provided
    if [ -n "$syzbot_config" ]; then
        echo
        apply_syzbot_config "$syzbot_config" "$build_dir"
    fi
    
    echo
    log "Configuration update complete."
    log "Run 'make olddefconfig' in the build directory to resolve dependencies."
    log "Build directory: $build_dir"
}

main "$@"
