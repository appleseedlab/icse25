#!/bin/bash

# Path to the CSV file
csv_file="/home/anon/research/config_tag.csv"

# Directory to store kernel images
output_dir="/home/anon/research/kernel_images/"

linux_next_dir="/home/anon/linux-next/"

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
    cp "/home/anon/research/syzbot_configuration_files/$config_file" $linux_next_dir.config
    
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
