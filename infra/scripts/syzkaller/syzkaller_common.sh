#!/bin/bash
#
# Syzkaller common functions (sourced by other syzkaller scripts).
#
# Provides: config generation, config discovery/selection, prerequisite checks.
# Requires: config.sh to be sourced first (so KERNEL_DEV_ENV_ROOT, SYZKALLER_BUILD_DIR,
#           SHARED_SYZKALLER_DIR, VM_SYZKALLER_DIR, KERNEL_BUILD_DIR, KBUILDDIR are set).
#
# Usage from a script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/../config.sh"
#   source "$SCRIPT_DIR/syzkaller_common.sh"
#

# Kernel build dir for syzkaller: use KBUILDDIR if set (timestamped build), else KERNEL_BUILD_DIR/syzkaller
get_syzkaller_kernel_build_dir() {
    if [ -n "${KBUILDDIR:-}" ] && [ -d "$KBUILDDIR" ]; then
        echo "$KBUILDDIR"
    else
        echo "${KERNEL_BUILD_DIR:-$OPEN_DIR/build/linux}/syzkaller"
    fi
}

# Check that syz-manager, kernel bzImage, and VM image exist. Exits on failure.
# Optional first argument: kernel build dir; if not set, uses get_syzkaller_kernel_build_dir.
check_syzkaller_prerequisites() {
    local kernel_build="${1:-$(get_syzkaller_kernel_build_dir)}"
    local syz_build="${SYZKALLER_BUILD_DIR:-}"
    local image_dir="${VM_SYZKALLER_DIR:-}"

    if [ -z "$syz_build" ] || [ ! -f "$syz_build/bin/syz-manager" ]; then
        echo "ERROR: syz-manager not found. Run setup_syzkaller.sh first." >&2
        exit 1
    fi
    if [ ! -f "$kernel_build/arch/x86/boot/bzImage" ]; then
        echo "ERROR: Kernel bzImage not found at $kernel_build/arch/x86/boot/bzImage. Run build_syzkaller_kernel.sh or set KBUILDDIR." >&2
        exit 1
    fi
    if [ -z "$image_dir" ] || [ ! -f "$image_dir/trixie.img" ]; then
        echo "ERROR: Debian image not found. Run create_syzkaller_image.sh first." >&2
        exit 1
    fi
}

# Generate a default syzkaller JSON config to the given path.
# Uses: SHARED_SYZKALLER_DIR, SYZKALLER_BUILD_DIR, VM_SYZKALLER_DIR, and kernel build from get_syzkaller_kernel_build_dir.
# Optional second argument: kernel build dir to use instead.
generate_default_syzkaller_config() {
    local output_path="$1"
    local kernel_build="${2:-$(get_syzkaller_kernel_build_dir)}"
    local shared="${SHARED_SYZKALLER_DIR:-}"
    local syz_build="${SYZKALLER_BUILD_DIR:-}"
    local image_dir="${VM_SYZKALLER_DIR:-}"

    if [ -z "$output_path" ] || [ -z "$shared" ] || [ -z "$syz_build" ] || [ -z "$image_dir" ]; then
        echo "ERROR: generate_default_syzkaller_config: required env vars not set (source config.sh first)." >&2
        return 1
    fi

    mkdir -p "$(dirname "$output_path")"
    cat > "$output_path" << EOF
{
	"target": "linux/amd64",
	"http": "127.0.0.1:56741",
	"workdir": "$shared/workdir",
	"kernel_obj": "$kernel_build",
	"image": "$image_dir/trixie.img",
	"sshkey": "$image_dir/trixie.id_rsa",
	"syzkaller": "$syz_build",
	"procs": 8,
	"type": "qemu",
	"vm": {
		"count": 4,
		"kernel": "$kernel_build/arch/x86/boot/bzImage",
		"cpu": 2,
		"mem": 2048
	}
}
EOF
}

# Select or create syzkaller config file. Sets CONFIG_FILE in the caller's scope.
# Arguments: optional --config /path/to/file to use that file directly.
# Otherwise: discover .cfg in SHARED_SYZKALLER_DIR; use default or interactive choice; generate default if missing.
# Returns (sets CONFIG_FILE); exits on error.
select_or_create_syzkaller_config() {
    local user_config=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config) user_config="${2:-}"; shift 2 ;;
            *) shift ;;
        esac
    done

    local shared="${SHARED_SYZKALLER_DIR:-}"
    local default_cfg="${shared}/syzkaller_manager.cfg"

    if [ -n "$user_config" ]; then
        if [ ! -f "$user_config" ]; then
            echo "ERROR: Specified config file not found: $user_config" >&2
            exit 1
        fi
        CONFIG_FILE="$user_config"
        echo "Using user-specified config: $CONFIG_FILE"
        return 0
    fi

    local existing=()
    if [ -d "$shared" ]; then
        while IFS= read -r -d '' f; do existing+=("$f"); done < <(find "$shared" -maxdepth 1 -type f -name "*.cfg" -print0 2>/dev/null || true)
    fi

    if [ ${#existing[@]} -gt 0 ]; then
        echo "Found existing Syzkaller config file(s):"
        for cfg in "${existing[@]}"; do echo "  - $(basename "$cfg")"; done
        echo

        if [ -f "$default_cfg" ]; then
            echo "Using existing default config: $(basename "$default_cfg")"
            CONFIG_FILE="$default_cfg"
        else
            if [ ! -t 0 ] || [ -n "${CI:-}" ]; then
                echo "Non-interactive mode: using first existing config: $(basename "${existing[0]}")"
                CONFIG_FILE="${existing[0]}"
            else
                echo -n "Create default config file ($(basename "$default_cfg"))? [y/N]: "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    CONFIG_FILE="$default_cfg"
                else
                    echo "Available config files:"
                    for i in "${!existing[@]}"; do echo "  $((i+1)). $(basename "${existing[$i]}")"; done
                    echo -n "Select config file number [1]: "
                    read -r selection
                    selection=${selection:-1}
                    if [ "$selection" -ge 1 ] && [ "$selection" -le ${#existing[@]} ]; then
                        CONFIG_FILE="${existing[$((selection-1))]}"
                    else
                        echo "ERROR: Invalid selection" >&2
                        exit 1
                    fi
                fi
            fi
        fi
    else
        CONFIG_FILE="$default_cfg"
    fi

    if [ "$CONFIG_FILE" = "$default_cfg" ] && [ ! -f "$CONFIG_FILE" ]; then
        echo "Generating default config file: $(basename "$CONFIG_FILE")"
        generate_default_syzkaller_config "$CONFIG_FILE" || exit 1
        echo "Config file created: $CONFIG_FILE"
        echo
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ERROR: Config file not found: $CONFIG_FILE" >&2
        exit 1
    fi
    echo "Using config file: $CONFIG_FILE"
    echo
}
