#!/bin/bash

# Ensure script is executed with three arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <linux_source_directory> <kernel_image_save_path> <kernel_version>"
    exit 1
fi

linuxsrc="$1"
kernel_image_save_path="$2"
kernel_version="$3"

set -euxo pipefail

# Navigate to the Linux source directory and clean it up
cd "$linuxsrc"
git clean -dfx

# Checkout the specified kernel version
git checkout "v$kernel_version"

# Build the kernel
make allyesconfig
make -j"$(nproc)"

# Copy the compiled kernel image to the specified save path
cp "$linuxsrc/arch/x86/boot/bzImage" "$kernel_image_save_path"

