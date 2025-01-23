#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

# Path to the CSV file
csv_file="$REPO_ROOT/experiments/fuzzing/fuzzing_parameters.csv"

# Ensure all arguments are provided
if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <output_dir> <linux_next_dir> <configuration_files_dir> <experiment_type>"
    exit 1
fi

# Arguments and variables
output_dir=$(realpath "$1")
linux_next_dir=$(realpath "$2")
configuration_files_dir=$(realpath "$3")
experiment_type=$4

if [[ "$experiment_type" != "default" && "$experiment_type" != "repaired" ]]; then
    echo "Error: experiment_type must be either 'default' or 'repaired'"
    exit 1
fi

# Validate directories and files
if [[ ! -d "$linux_next_dir" ]]; then
    echo "Error: $linux_next_dir does not exist"
    exit 1
fi

if [[ ! -d "$configuration_files_dir" ]]; then
    echo "Error: $configuration_files_dir does not exist"
    exit 1
fi

if [[ ! -f "$csv_file" ]]; then
    echo "Error: $csv_file does not exist"
    exit 1
fi

# Adjust paths based on experiment type
if [[ "$experiment_type" == "default" ]]; then
    configuration_files_dir="$configuration_files_dir/syzbot_configuration_files"
    output_dir="$output_dir/default/"
else
    configuration_files_dir="$configuration_files_dir/repaired_configuration_files"
    output_dir="$output_dir/repaired/"
fi

mkdir -p "$output_dir"

log_file="$output_dir/build_kernel.log"
exec > >(tee -a "$log_file") 2>&1

echo "$(date +"%Y-%m-%d %H:%M:%S") Starting kernel build process"
echo "Log file: $log_file"
echo "Configuration files directory: $configuration_files_dir"
echo "Output directory: $output_dir"

# Array to store failed configurations
failed_configurations=()

cd "$linux_next_dir"

# Process the CSV file
while IFS=, read -r repair_commit_id syzbot_config_file linux_next_tag repaired_config_file default_archive repaired_archive; do
    config_file=$([[ "$experiment_type" == "default" ]] && echo "$syzbot_config_file" || echo "$repaired_config_file")

    echo "$(date +"%Y-%m-%d %H:%M:%S") Processing configuration: $config_file with linux-next tag: $linux_next_tag"

    # Clean and reset the repository
    git clean -dfx -q
    git reset --hard -q

    # Checkout the specified linux-next tag
    if ! git checkout "$linux_next_tag"; then
        echo "Error: Failed to checkout tag $linux_next_tag"
        failed_configurations+=("$config_file")
        continue
    fi

    # Generate base configurations
    make defconfig
    make kvm_guest.config

    # Replace .config with the provided configuration file
    if [[ ! -f "$configuration_files_dir/$config_file" ]]; then
        echo "Error: Configuration file $config_file not found in $configuration_files_dir"
        failed_configurations+=("$config_file")
        continue
    fi
    cp "$configuration_files_dir/$config_file" "$linux_next_dir/.config"

    # Add required configurations for syzkaller
    ./scripts/config --enable CONFIG_KCOV \
                     --enable CONFIG_DEBUG_INFO \
                     --enable CONFIG_DEBUG_INFO_DWARF4 \
                     --disable CONFIG_DEBUG_INFO_BTF \
                     --enable CONFIG_KASAN \
                     --enable CONFIG_KASAN_INLINE \
                     --enable CONFIG_CONFIGFS_FS \
                     --enable CONFIG_SECURITYFS \
                     --enable CONFIG_CMDLINE_BOOL \
                     --set-val CONFIG_CMDLINE "\"net.ifnames=0\""

    # Update the configuration
    make olddefconfig

    # Compile the kernel
    if ! make -j$(nproc); then
        echo "Error: Compilation failed for $config_file"
        failed_configurations+=("$config_file")
        continue
    fi

    # Check if the kernel images exist
    bzImage_path="$linux_next_dir/arch/x86/boot/bzImage"
    vmlinux_path="$linux_next_dir/vmlinux"
    if [[ ! -f "$bzImage_path" || ! -f "$vmlinux_path" ]]; then
        echo "Error: Kernel images missing for $config_file"
        failed_configurations+=("$config_file")
        continue
    fi

    # Archive and save kernel images
    config_name=$(basename "$config_file" .config)
    output_kernel_dir="$output_dir/${config_name}_${repair_commit_id}_${linux_next_tag}_kernel"
    mkdir -p "$output_kernel_dir"
    mv "$bzImage_path" "$vmlinux_path" "$output_kernel_dir"

    echo "$(date +"%Y-%m-%d %H:%M:%S") Finished processing $config_file with $linux_next_tag"
    echo "---------------------------------------------"

done < "$csv_file"

# Report failed configurations
if [[ ${#failed_configurations[@]} -gt 0 ]]; then
    echo "The following configuration files failed to compile or produce kernel images:"
    for config in "${failed_configurations[@]}"; do
        echo "$config"
    done
fi

