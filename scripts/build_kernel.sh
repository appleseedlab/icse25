#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

# Path to the CSV file
csv_file="$REPO_ROOT/repairer_script/config_tag.csv"

# Directory to store kernel images
output_dir=$1
linux_next_dir=$2
syzbot_configuration_files_dir=$REPO_ROOT/$3

# Check if there is a missing argument
if [ -z "$output_dir" ] || [ -z "$linux_next_dir" || "$syzbot_configuration_files_dir" ]; then
    echo "Usage: $0 <output_dir> <linux_next_dir> <syzbot_configuration_files_dir>"
    echo "Example: $0 /output/kernel_images/" \
        "/path/to/linux-next/ camera_ready_configuration_files/syzbot_configuration_files/"
    exit 1
fi

# Check if linux-next directory exists
if [ ! -d "$linux_next_dir" ]; then
    echo "Error: $linux_next_dir does not exist"
    exit 1
fi

# Check if syzbot configuration files directory exists
if [ ! -d "$syzbot_configuration_files_dir" ]; then
    echo "Error: $syzbot_configuration_files_dir does not exist"
    exit 1
fi

# Check if the CSV file exists
if [ ! -f "$csv_file" ]; then
    echo "Error: $csv_file does not exist"
    exit 1
fi

# Ensure the output directory exists
mkdir -p "$output_dir"

cd $linux_next_dir

# Iterate through each line of the CSV file
while IFS=, read -r config_file linux_next_tag
do
    echo "Processing configuration: $config_file with linux-next tag: $linux_next_tag"

    # Checkout the specified linux-next tag
    echo "Checking out linux-next tag: $linux_next_tag"
    git checkout "$linux_next_tag"

    # Generate a default configuration file
    echo "Generating a default configuration file"
    make defconfig

    # Replace the generated .config with the specified configuration file
    echo "Replacing the generated .config with $config_file"

    # Check if config_file exists
    if [ ! -f "$syzbot_configuration_files_dir/$config_file" ]; then
        echo "Error: $config_file does not exist in $syzbot_configuration_files_dir"
        exit 1
    fi

    cp "$syzbot_configuration_files_dir/$config_file" $linux_next_dir.config

    make kvm_guest.config

    # Add configurations required for syzkaller
    echo "Appending configurations for syzkaller"
    echo "CONFIG_KCOV=y" >> $linux_next_dir.config
    echo "CONFIG_DEBUG_INFO_DWARF4=y" >> $linux_next_dir.config
    echo "CONFIG_KASAN=y" >> $linux_next_dir.config
    echo "CONFIG_CONFIGFS_FS=y" >> $linux_next_dir.config
    echo "CONFIG_SECURITYFS=y" >> $linux_next_dir.config

    # Update the configuration using olddefconfig
    echo "Updating configuration with olddefconfig"
    make olddefconfig

    # Compile the kernel
    echo "Compiling the kernel"
    make -j$(nproc)

    # Formulate the output file name
    config_name=$(basename "$config_file" .config)
    output_file="${output_dir}${config_name}_${linux_next_tag}_bzImage"

    # Store the kernel image
    echo "Storing the kernel image as $output_file"
    cp "$linux_next_dir"arch/x86/boot/bzImage "$output_file"

    echo "Finished processing $config_file with $linux_next_tag"
    echo "---------------------------------------------"

done < "$csv_file"
