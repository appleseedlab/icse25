#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0"
    echo ""
    echo "This script reads configurations from a CSV file, checks out the kernel source to the"
    echo "specified commit, applies configuration files, builds the kernel, and measures the"
    echo "time taken for the build."
    echo ""
    echo "Environment Assumptions:"
    echo "  1. KERNEL_SRC points to a valid kernel source directory (default: <repo_root>/linux-next)"
    echo "  2. SRC_CSV_FILE points to a CSV file with configuration details (default: <repo_root>/experiments/RQ2/table5/repaired_configs.csv)"
    echo "  3. CONFIGS_DIR points to a directory containing configuration files (default: <repo_root>/configuration_files/syzbot_configuration_files)"
    echo ""
    echo "Output:"
    echo "  Build times are saved to a CSV file in the same directory as the script (default: build_times.csv)"
    echo ""
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../../../")"

KERNEL_SRC="$REPO_ROOT/linux-next"
SRC_CSV_FILE="$REPO_ROOT/experiments/RQ2/table5/repaired_configs.csv"
CONFIGS_DIR="$REPO_ROOT/configuration_files/syzbot_configuration_files"
OUTPUT_CSV_FILE="$SCRIPT_DIR/build_times.csv"

# Validate paths
if [ ! -d "$KERNEL_SRC" ]; then
    echo "[-] Error: Kernel source directory ($KERNEL_SRC) does not exist."
    usage
fi

if [ ! -f "$SRC_CSV_FILE" ]; then
    echo "[-] Error: Source CSV file ($SRC_CSV_FILE) does not exist."
    usage
fi

if [ ! -d "$CONFIGS_DIR" ]; then
    echo "[-] Error: Configuration directory ($CONFIGS_DIR) does not exist."
    usage
fi

# Read config_name, kernel_id, commit_id from csv file
while IFS=, read -r commit_id config_name kernel_id
do
    (cd "$KERNEL_SRC" && git clean -dfx -q)

    # Checkout to the kernel_id
    (cd "$KERNEL_SRC" && git checkout -f "$kernel_id" -q)

    # Copy config file to .config
    cp "$CONFIGS_DIR/$config_name" "$KERNEL_SRC/.config"

    # Make olddefconfig
    (cd "$KERNEL_SRC" && make olddefconfig)

    # Measure the build time
    build_time=$(cd "$KERNEL_SRC" && (time -p make -j$(nproc)) 2>&1 | grep "^real" | awk '{print $2}')

    if [ $? -eq 0 ]; then
        echo "$config_name,$kernel_id,$commit_id,$build_time" >> "$OUTPUT_CSV_FILE"
    else
        echo "$config_name,$kernel_id,$commit_id,-1" >> "$OUTPUT_CSV_FILE"
    fi

done < "$SRC_CSV_FILE"

echo "Build times are saved to $OUTPUT_CSV_FILE"
