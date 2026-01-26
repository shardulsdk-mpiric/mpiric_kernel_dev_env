#!/bin/bash
#
# Print Kernel Development Environment Variables
#
# This script sources config.sh and prints all environment variables
# set by the configuration system.
#
# Usage: ./printvars.sh
#        Or: source infra/scripts/config.sh && printvars

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

printvars

