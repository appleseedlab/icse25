#!/bin/bash

set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

echo "$SCRIPT_DIR"
exit 1

KERNEL_SRC="$REPO_ROOT/linux-next"
SRC_CSV_FILE="$REPO_ROOT/experiments/RQ2/table5/repaired_configs.csv"
CONFIGS_DIR="$REPO_ROOT/camera_ready/configuration_files/syzbot_configuration_files"

# Read config_name, kernel_id, commit_id from csv file

while IFS=, read -r commit_id config_name kernel_id
do
    (cd $KERNEL_SRC; git clean -dfx)

    # checkout to the kernel_id
    (cd $KERNEL_SRC; git checkout $kernel_id)

    # copy config file to .config
    cp $CONFIGS_DIR/$config_name $KERNEL_SRC/.config

    # make olddefconfig
    (cd $KERNEL_SRC; make olddefconfig)

    # grep the build time from time command output, and save it to a file
    # if the build fails, save commit_id, kernel_id, and build time as -1
    build_time=$(cd $KERNEL_SRC; (time -p make -j$(nproc)) 2>&1 | grep "^real" | awk '{print $2}')

    if [ $? -eq 0 ]; then
        echo "$config_name,$kernel_id,$commit_id,$build_time" >> $SCRIPT_DIR/build_times.csv
    else
        echo "$config_name,$kernel_id,$commit_id,-1" >> $SCRIPT_DIR/build_times.csv
    fi

done < $SRC_CSV_FILE
