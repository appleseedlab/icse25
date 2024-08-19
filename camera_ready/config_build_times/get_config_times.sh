#!/bin/bash

set -x

KERNEL_SRC=/home/sanan/linux-next
SRC_CSV_FILE=repaired_configs.csv

# Read config_name, kernel_id, commit_id from csv file

while IFS=, read -r commit_id config_name kernel_id
do
    # git clean
    (cd $KERNEL_SRC; git clean -dfx)

    # checkout to the kernel_id
    (cd $KERNEL_SRC; git checkout $kernel_id)

    # copy config file to .config
    cp /home/sanan/research/syzbot_configuration_files/$config_name $KERNEL_SRC/.config

    # make olddefconfig
    config_time=$(cd $KERNEL_SRC; (time -p make olddefconfig) 2>&1 | grep "^real" | awk -F' ' '{print $2}')

    echo "$config_name,$kernel_id,$commit_id,$config_time" >> config_times.csv

done < $SRC_CSV_FILE
