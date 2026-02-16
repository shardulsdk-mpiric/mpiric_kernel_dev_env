#!/bin/bash

# Start syzkaller manager in a detached screen session with log rotation.
#
# Use this for long-running fuzzing: manager runs in screen, logs rotate by size.
# Caller must provide the config file via -config (absolute or relative path).
#
# In kernel dev env: sources infra/scripts/config.sh (printvars-style variables).

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source kernel dev env config when script is under repo (infra/scripts/syzkaller or shared/syzkaller).
# Sets KERNEL_DEV_ENV_ROOT, SYZKALLER_BUILD_DIR, KBUILDDIR, SHARED_SYZKALLER_DIR, etc.
if [ -z "$KERNEL_DEV_ENV_ROOT" ]; then
    _D="$SCRIPT_DIR"
    while [ -n "$_D" ] && [ "$_D" != "/" ]; do
        if [ -f "$_D/infra/scripts/config.sh" ]; then
            # shellcheck source=/dev/null
            source "$_D/infra/scripts/config.sh"
            break
        fi
        _D="$(cd "$_D/.." 2>/dev/null && pwd)"
    done
    unset _D
fi

# Base directory for syzkaller data (e.g. logs): use env when set, else script dir
SYZKALLER_BASE="${SHARED_SYZKALLER_DIR:-$SCRIPT_DIR}"

# Syzkaller binary: use build dir from config when available, else script-relative
if [ -n "$SYZKALLER_BUILD_DIR" ] && [ -x "${SYZKALLER_BUILD_DIR}/bin/syz-manager" ]; then
    BIN_PATH="${SYZKALLER_BUILD_DIR}/bin/syz-manager"
else
    BIN_PATH="$SCRIPT_DIR/bin/syz-manager"
fi
ENV_PATH="$SCRIPT_DIR/tools/syz-env"

# Config file: set via -config argument (required when starting manager; not used for --cleanup)
CFG_PATH=""

# --- Argument parsing ---
CLEANUP_REQUESTED=0
usage() {
    echo "Usage: $0 -config <path>     Start syz-manager with the given config file (absolute or relative)"
    echo "       $0 --cleanup          Stop syz-manager screen session and remove runtime files"
    echo ""
    echo "The caller is responsible for creating and maintaining the syzkaller config file."
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        -config)
            if [[ -z "${2:-}" ]]; then
                echo "Error: -config requires a path argument." >&2
                usage >&2
                exit 1
            fi
            CFG_PATH="$2"
            shift 2
            ;;
        --cleanup)
            CLEANUP_REQUESTED=1
            shift
            break
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Resolve CFG_PATH to absolute path when set (relative paths are relative to current working directory)
if [ -n "$CFG_PATH" ]; then
    if [ -d "$(dirname "$CFG_PATH")" ]; then
        CFG_PATH="$(cd "$(dirname "$CFG_PATH")" && pwd)/$(basename "$CFG_PATH")"
    fi
fi

# Screen session name
SCREEN_SESSION="syz_manager_session"

# Log rotation settings
LOG_ROOT_DIR="$SYZKALLER_BASE/syzkaller_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="$LOG_ROOT_DIR/run_$TIMESTAMP"
LOG_BASENAME="$LOG_DIR/syz_manager_log"
MAX_SIZE=$((2 * 1024 * 1024)) # 2MB size limit per log file

# Runtime files for storing PIDs and session info
RUNTIME_DIR="/tmp/syz-manager-runtime-$$"
PID_INFO_FILE="$RUNTIME_DIR/syz-manager.pidinfo"


# --- Log Rotation Function ---
# This function reads from standard input (piped from syz-manager) and writes
# to a log file. It checks the file size before each write and creates a new
# file (rotates) if the size limit is exceeded.
log_and_rotate() {
    # This function is designed to be executed in a subshell inside 'screen'.
    
    # Ensure the log directory for this run exists
    mkdir -p "$LOG_DIR"
    
    local current_log_file="${LOG_BASENAME}_$(date +"%Y%m%d_%H%M%S").log"
    echo "INFO: Initial log file is '$current_log_file'"

    # Read from stdin line by line
    while IFS= read -r line; do
        # Check if the current log file exists and get its size
        if [ -f "$current_log_file" ]; then
            # Using 'stat --format="%s"' which is common on Linux systems.
            # If on BSD/macOS, you might need 'stat -f%z'.
            local size
            size=$(stat --format="%s" "$current_log_file" 2>/dev/null || echo 0)
            
            # If size exceeds the max limit, rotate the log
            if (( size >= MAX_SIZE )); then
                echo "[LOG_ROTATOR] Log file size ($size bytes) reached limit. Rotating." | tee -a "$current_log_file"
                current_log_file="${LOG_BASENAME}_$(date +"%Y%m%d_%H%M%S").log"
                echo "[LOG_ROTATOR] New log file is: $current_log_file"
            fi
        fi
        
        # Append the line from syz-manager to the current log file
        echo "$line" >> "$current_log_file"
    done
    
    echo "[LOG_ROTATOR] syz-manager output stream ended. Log rotator is exiting." >> "$current_log_file"
}

# Export the function so it's available to the 'bash -c' subshell used by screen
export -f log_and_rotate

# --- Main Script Logic ---

# 1. Handle --cleanup flag
if [[ "$CLEANUP_REQUESTED" == "1" ]]; then
    echo "Cleaning up syzkaller manager session and temp files..."
    
    # Terminate the screen session, which kills all processes inside it
    screen -S "$SCREEN_SESSION" -X quit 2>/dev/null
    
    # Find and remove any leftover runtime directories
    rm -rf /tmp/syz-manager-runtime-*
    
    echo "Cleanup complete."
    exit 0
fi

# 2. Check if screen session already exists and attach to it
if screen -list | grep -q "\.${SCREEN_SESSION}\s"; then
    echo "Screen session '$SCREEN_SESSION' is already running."
    echo "Attaching to the existing session..."
    screen -r "$SCREEN_SESSION"
    exit 0
fi

# 3. Start a new session
if [ -z "$CFG_PATH" ]; then
    echo "Error: syzkaller config file required. Use -config <path> to specify the config file." >&2
    usage >&2
    exit 1
fi
if [ ! -f "$BIN_PATH" ]; then
    echo "Error: syz-manager binary not found at '$BIN_PATH'"
    exit 1
fi
if [ ! -f "$CFG_PATH" ]; then
    echo "Error: syzkaller config not found at '$CFG_PATH'"
    exit 1
fi

# Create the directory for runtime files
mkdir -p "$RUNTIME_DIR"

# Export variables needed by the log_and_rotate function in the subshell
export LOG_DIR
export LOG_BASENAME
export MAX_SIZE

echo "Starting syz-manager in new detached screen session: $SCREEN_SESSION"
echo "Log files will be stored in: $LOG_DIR"

# The command to run inside screen. It pipes the syz-manager output (stdout & stderr)
# directly to our log_and_rotate function.
# CMD_TO_RUN="$BIN_PATH -debug -config '$CFG_PATH' -debug 2>&1 | log_and_rotate"
 CMD_TO_RUN="$BIN_PATH -config '$CFG_PATH' 2>&1 | log_and_rotate"

# Start the detached screen session
screen -dmS "$SCREEN_SESSION" bash -c "$CMD_TO_RUN"

# Wait a moment for the process to start
sleep 2

# Fetch the PID of the running syz-manager for user info
# SYZ_PID=$(pgrep -f "$BIN_PATH -debug -config $CFG_PATH")
SYZ_PID=$(pgrep -f "$BIN_PATH -config $CFG_PATH")

if [ -z "$SYZ_PID" ]; then
    echo "Error: Failed to start syz-manager."
    echo "Attach to the screen session to debug: screen -r $SCREEN_SESSION"
    rm -rf "$RUNTIME_DIR"
    exit 1
fi

# Save session and process info to the pidinfo file
{
    echo "Screen session name: $SCREEN_SESSION"
    echo "To attach: screen -r $SCREEN_SESSION"
    echo "To detach: Press Ctrl+A then D"
    echo "PID: $SYZ_PID"
    echo "Log Directory: $LOG_DIR"
    echo "Runtime files: $RUNTIME_DIR"
} > "$PID_INFO_FILE"

# Notify user with all the details
echo "--------------------------------------------------------"
cat "$PID_INFO_FILE"
echo "--------------------------------------------------------"
echo "syz-manager is running successfully."
echo "To cleanup later, run: $0 --cleanup"
echo "To run again, use: $0 -config <path-to-cfg>"
