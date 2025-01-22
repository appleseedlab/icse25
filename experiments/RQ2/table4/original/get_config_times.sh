#!/bin/bash

# Usage function
usage() {
    echo "Usage: bash $0 [KERNEL_SRC] [SRC_CSV_FILE] [CONFIGS_DIR]"
    echo ""
    echo "This script reads configurations from a CSV file, checks out the kernel source to the"
    echo "specified commit, applies configuration files, and measures the time taken to run"
    echo "'make olddefconfig'."
    echo ""
    echo "Arguments:"
    echo "  KERNEL_SRC     Path to the kernel source directory (default: <repo_root>/linux-next)"
    echo "  SRC_CSV_FILE   Path to the CSV file with configuration details (default: <script_dir>/../repaired_configs.csv)"
    echo "  CONFIGS_DIR    Path to the directory containing configuration files (default: <repo_root>/configuration_files/syzbot_configuration_files)"
    echo ""
    echo "Example:"
    echo "  $0 /path/to/kernel/src /path/to/configs.csv /path/to/configs_dir"
    echo ""
}

# Error handling function
error_exit() {
    echo "[-] Error: $1"
    usage
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || error_exit "Failed to get script directory."
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../../../")" || error_exit "Failed to resolve repository root."

default_kernel_src="$REPO_ROOT/linux-next/1"

# Assign default or provided arguments
KERNEL_SRC=${1:-$default_kernel_src}
KERNEL_SRC="$(realpath "$KERNEL_SRC" 2>/dev/null || true)"

# Exit if kernel source directory does not exist or path is invalid
if [ ! -d "$KERNEL_SRC" ]; then
    error_exit "Kernel source directory does not exist. Please provide the correct path."
fi

default_src_csv_file="$SCRIPT_DIR/../repaired_configs.csv"
SRC_CSV_FILE=${2:-$default_src_csv_file}
SRC_CSV_FILE="$(realpath "$SRC_CSV_FILE" 2>/dev/null || true)"

default_configs_dir="$REPO_ROOT/configuration_files/syzbot_configuration_files"
CONFIGS_DIR=${3:-$default_configs_dir}
CONFIGS_DIR="$(realpath "$CONFIGS_DIR" 2>/dev/null || true)"

# Check if source CSV file exists
if [ ! -f "$SRC_CSV_FILE" ]; then
    error_exit "Source CSV file does not exist. Please provide a valid file."
fi

# Check if configurations directory exists
if [ ! -d "$CONFIGS_DIR" ]; then
    error_exit "Configurations directory does not exist. Please provide a valid directory."
fi

# Read config_name, kernel_id, commit_id from CSV file
while IFS=, read -r commit_id config_name kernel_id
do
    # Checkout to the kernel_id
    (cd "$KERNEL_SRC" && git checkout -f "$kernel_id" -q) || error_exit "Failed to checkout kernel commit: $kernel_id"

    # Make defconfig
    (cd "$KERNEL_SRC" && make defconfig) || error_exit "Failed to run 'make defconfig'."

    # Copy config file to .config
    cp "$CONFIGS_DIR/$config_name" "$KERNEL_SRC/.config" || error_exit "Failed to copy configuration file: $config_name"

    # Make olddefconfig
    config_time=$(cd "$KERNEL_SRC" && (time -p make olddefconfig) 2>&1 | grep "^real" | awk -F' ' '{print $2}') || error_exit "Failed to run 'make olddefconfig'."

    echo "$config_name,$kernel_id,$commit_id,$config_time" >> "$SCRIPT_DIR/config_times.csv" || error_exit "Failed to write to CSV file."

done < "$SRC_CSV_FILE" || error_exit "Failed to read CSV file."

echo "Config times are saved in $SCRIPT_DIR/config_times.csv"
