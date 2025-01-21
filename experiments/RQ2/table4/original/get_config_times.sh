#!/bin/bash

set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../../../")"

default_kernel_src="$REPO_ROOT/linux-next"

KERNEL_SRC=${1:-$default_kernel_src}
KERNEL_SRC="$(realpath $KERNEL_SRC)"

# exit if kernel source directory does not exist
if [ ! -d "$KERNEL_SRC" ]; then
    echo "[-] Kernel source directory does not exist. Please provide the correct path."
    exit 1
fi

default_src_csv_file="$SCRIPT_DIR/../repaired_configs.csv"
SRC_CSV_FILE=${2:-$default_src_csv_file}
SRC_CSV_FILE="$(realpath $SRC_CSV_FILE)"

default_configs_dir="$REPO_ROOT/configuration_files/syzbot_configuration_files"
CONFIGS_DIR=${3:-$default_configs_dir}
CONFIGS_DIR="$(realpath $CONFIGS_DIR)"

# Read config_name, kernel_id, commit_id from csv file

while IFS=, read -r commit_id config_name kernel_id
do
    # checkout to the kernel_id
    (cd $KERNEL_SRC; git -f checkout $kernel_id -q)

    # make defconfig
    (cd $KERNEL_SRC; make defconfig)

    # copy config file to .config
    cp $CONFIGS_DIR/$config_name $KERNEL_SRC/.config

    # make olddefconfig
    config_time=$(cd $KERNEL_SRC; (time -p make olddefconfig) 2>&1 | grep "^real" | awk -F' ' '{print $2}')

    echo "$config_name,$kernel_id,$commit_id,$config_time" >> $SCRIPT_DIR/config_times.csv

done < $SRC_CSV_FILE

echo "Config times are saved in $SCRIPT_DIR/config_times.csv"
