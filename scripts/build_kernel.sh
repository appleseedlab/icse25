#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

# Path to the CSV file
csv_file="$REPO_ROOT/experiments/fuzzing/fuzzing_parameters.csv"

# Directory to store kernel images
output_dir=$(realpath $1)
linux_next_dir=$(realpath $2)
configuration_files_dir=$(realpath $3)
experiment_type=$4
if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <output_dir> <linux_next_dir> <configuration_files_dir> <experiment_type>"
    exit 1
fi

# if experiment_type is not either 'default' or 'repaired', exit
if [ "$experiment_type" != "default" ] && [ "$experiment_type" != "repaired" ]; then
    echo "Error: experiment_type must be either 'default' or 'repaired'"
    exit 1
fi

# Check if linux-next directory exists
if [ ! -d "$linux_next_dir" ]; then
    echo "Error: $linux_next_dir does not exist"
    exit 1
fi

# Check if syzbot configuration files directory exists
if [ ! -d "$configuration_files_dir" ]; then
    echo "Error: $configuration_files_dir does not exist"
    exit 1
fi

# Check if the CSV file exists
if [ ! -f "$csv_file" ]; then
    echo "Error: $csv_file does not exist"
    exit 1
fi


syzbot_configuration_files_dir="$configuration_files_dir/syzbot_configuration_files"
repaired_configuration_files_dir="$configuration_files_dir/repaired_configuration_files"

if [ "$experiment_type" == "default" ]; then
    configuration_files_dir=$syzbot_configuration_files_dir
    output_dir="$output_dir/default/"
else
    configuration_files_dir=$repaired_configuration_files_dir
    output_dir="$output_dir/repaired/"
fi

# Ensure the output directory exists
mkdir -p "$output_dir"

log_file="$output_dir/build_kernel.log"
exec 1> $log_file 2>&1

echo "Log file: $log_file"
echo "Configuration files directory: $configuration_files_dir"
echo "Output directory: $output_dir"

# an array to store the names of the configuration files that failed to compile
failed_configurations=()

cd $linux_next_dir

# Iterate through each line of the CSV file
while IFS=, read -r repair_commit_id syzbot_config_file linux_next_tag repaired_config_file
do
    if [ "$experiment_type" == "default" ]; then
        config_file=$syzbot_config_file
    else
        config_file=$repaired_config_file
    fi

    echo "Processing configuration: $config_file with linux-next tag: $linux_next_tag"

    echo "Cleaning the kernel source tree"
    git clean -dfx -q

    echo "Resetting the kernel source tree"
    git reset --hard -q

    # Checkout the specified linux-next tag
    echo "Checking out linux-next tag: $linux_next_tag"
    git checkout "$linux_next_tag"

    # Generate a default configuration file
    echo "Generating a default configuration file"
    make defconfig
    make kvm_guest.config

    # Replace the generated .config with the specified configuration file
    echo "Replacing the generated .config with $config_file"

    cp "$configuration_files_dir/$config_file" $linux_next_dir.config

    # Add configurations required for syzkaller
    ./scripts/config --enable CONFIG_KCOV \
                 --enable CONFIG_DEBUG_INFO \
                 --enable CONFIG_DEBUG_INFO_DWARF4 \
                 --enable CONFIG_KASAN \
                 --enable CONFIG_KASAN_INLINE \
                 --enable CONFIG_CONFIGFS_FS \
                 --enable CONFIG_SECURITYFS \
                 --enable CONFIG_CMDLINE_BOOL \
                 --set-val CONFIG_CMDLINE "\"net.ifnames=0\""


    # Update the configuration using olddefconfig
    echo "Updating configuration with olddefconfig"
    make olddefconfig

    # Compile the kernel
    echo "Compiling the kernel"
    make -j$(nproc) || {
        echo "Error: Compilation failed";
        failed_configurations+=("$config_file");
        continue;
    }

    # Formulate the output file name
    config_name=$(basename "$config_file" .config)
    output_kernel_dir="${output_dir}/${config_file}_${repair_commit_id}_kernel"

    # Store the kernel image
    echo "Storing the kernel image as $output_kernel_dir"
    bzImage_path="$linux_next_dir/arch/x86/boot/bzImage"
    vmlinux_path="$linux_next_dir/vmlinux"
    archive_name="${config_name}_${linux_next_tag}.7z"
    7z a $archive_name "$bzImage_path" "$vmlinux_path"
    cp $archive_name "$output_kernel_dir"

    echo "Finished processing $config_file with $linux_next_tag"
    echo "---------------------------------------------"

done < "$csv_file"

# Print the names of the configuration files that failed to compile
if [ ${#failed_configurations[@]} -gt 0 ]; then
    echo "The following configuration files failed to compile:"
    for config in "${failed_configurations[@]}"; do
        echo "$config"
    done
fi
