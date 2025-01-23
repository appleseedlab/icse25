#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0"
    echo ""
    echo "This script reads configurations from a CSV file, checks out the kernel source to the"
    echo "specified commit, applies patches, repairs configuration files, builds the kernel, and"
    echo "measures the time taken for each step."
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

# Read config_name, kernel_id, commit_id from the CSV file
while IFS=, read -r commit_id config_name kernel_id
do
<<<<<<< HEAD
    # Clean the repo
    (cd "$KERNEL_SRC" && git clean -dfx -q)
=======
    # clean the repo
    (cd $KERNEL_SRC; git clean -dfx -q)
>>>>>>> master

    # Git checkout to kernel_id
    (cd "$KERNEL_SRC" && git checkout -f "$kernel_id")

    # Get patch diff
    (cd "$KERNEL_SRC" && git show "$commit_id" > patch.diff)

<<<<<<< HEAD
    # Use klocalizer to repair the config file and measure the time
    klocalizer_config_time=$(cd "$KERNEL_SRC" && (time -p klocalizer -v -a x86_64 --repair "$CONFIGS_DIR/$config_name" --include-mutex "$KERNEL_SRC/patch.diff" --formulas ../formulacache --define CONFIG_KCOV --define CONFIG_DEBUG_INFO_DWARF4 --define CONFIG_KASAN --define CONFIG_KASAN_INLINE --define CONFIG_CONFIGFS_FS --define CONFIG_SECURITYFS --define CONFIG_CMDLINE_BOOL; rm -rf koverage_files/) 2>&1 | grep "^real" | awk -F' ' '{print $2}' )
=======
    # use klocalizer to repair the config file and measure the time
    klocalizer_config_time=$(cd $KERNEL_SRC; (time -p klocalizer -v -a x86_64 --repair "$CONFIGS_DIR/$config_name" --include-mutex $KERNEL_SRC/patch.diff --formulas ../formulacache --define CONFIG_KCOV --define CONFIG_DEBUG_INFO_DWARF4 --define CONFIG_KASAN --define CONFIG_KASAN_INLINE --define CONFIG_CONFIGFS_FS --define CONFIG_SECURITYFS --define CONFIG_CMDLINE_BOOL; rm -rf koverage_files/;) 2>&1 | grep "^real" | awk -F' ' '{print $2}' )
>>>>>>> master

    # Copy repaired config file to .config
    (cd "$KERNEL_SRC" && cp 0-x86_64.config "$KERNEL_SRC/.config")

    # Make olddefconfig
    (cd "$KERNEL_SRC" && make olddefconfig)

    # Measure the build time
    build_time=$(cd "$KERNEL_SRC" && (time -p make -j$(nproc)) 2>&1 | grep "^real" | awk '{print $2}')

    if [ $? -eq 0 ]; then
<<<<<<< HEAD
        echo "$config_name,$kernel_id,$commit_id,$build_time" >> "$OUTPUT_CSV_FILE"
    else
        echo "$config_name,$kernel_id,$commit_id,-1" >> "$OUTPUT_CSV_FILE"
=======
        echo "$config_name,$kernel_id,$commit_id,$build_time" >> $OUTPUT_CSV_FILE
    else
        echo "$config_name,$kernel_id,$commit_id,-1" >> $OUTPUT_CSV_FILE
>>>>>>> master
    fi

done < "$SRC_CSV_FILE"
