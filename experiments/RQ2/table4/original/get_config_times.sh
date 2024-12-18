#!/bin/bash

set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

KERNEL_SRC="$REPO_ROOT/../../../linux-next"
# exit if kernel source directory does not exist
if [ ! -d "$KERNEL_SRC" ]; then
    echo "[-] Kernel source directory does not exist. Please provide the correct path."
    exit 1
fi

SRC_CSV_FILE="$SCRIPT_DIR/../repaired_configs.csv"
CONFIGS_DIR="$REPO_ROOT/../../../camera_ready/configuration_files/syzbot_configuration_files"

# Read config_name, kernel_id, commit_id from csv file

while IFS=, read -r commit_id config_name kernel_id
do
    # checkout to the kernel_id
    (cd $KERNEL_SRC; git checkout $kernel_id)

    # make defconfig
    (cd $KERNEL_SRC; make defconfig)

    # copy config file to .config
    cp $CONFIGS_DIR/$config_name $KERNEL_SRC/.config

    # make olddefconfig
    config_time=$(cd $KERNEL_SRC; (time -p make olddefconfig) 2>&1 | grep "^real" | awk -F' ' '{print $2}')

    echo "$config_name,$kernel_id,$commit_id,$config_time" >> $SCRIPT_DIR/config_times.csv

done < $SRC_CSV_FILE
