#!/bin/bash

set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../../../")"

KERNEL_SRC="$REPO_ROOT/linux-next"
SRC_CSV_FILE="$REPO_ROOT/experiments/RQ2/table5/repaired_configs.csv"
CONFIGS_DIR="$REPO_ROOT/configuration_files/syzbot_configuration_files"
OUTPUT_CSV_FILE="$SCRIPT_DIR/build_times.csv"

# Read config_name, kernel_id, commit_id from csv file

while IFS=, read -r commit_id config_name kernel_id
do
    # clean the repo
    (cd $KERNEL_SRC; git clean -dfx -q)

    # git checkout to kernel_id
    (cd $KERNEL_SRC; git checkout -f $kernel_id)

    # get patch diff
    (cd $KERNEL_SRC; git show $commit_id > patch.diff)

    # use klocalizer to repair the config file and measure the time
    klocalizer_config_time=$(cd $KERNEL_SRC; (time -p klocalizer -v -a x86_64 --repair "$CONFIGS_DIR/$config_name" --include-mutex $KERNEL_SRC/patch.diff --formulas ../formulacache --define CONFIG_KCOV --define CONFIG_DEBUG_INFO_DWARF4 --define CONFIG_KASAN --define CONFIG_KASAN_INLINE --define CONFIG_CONFIGFS_FS --define CONFIG_SECURITYFS --define CONFIG_CMDLINE_BOOL; rm -rf koverage_files/;) 2>&1 | grep "^real" | awk -F' ' '{print $2}' )

    # copy repaired config file to .config
    (cd $KERNEL_SRC; cp 0-x86_64.config $KERNEL_SRC/.config)

    # make olddefconfig
    (cd $KERNEL_SRC; make olddefconfig)

    # grep the build time from time command output, and save it to a file
    # if the build fails, save commit_id, kernel_id, and build time as -1
    build_time=$(cd $KERNEL_SRC; (time -p make -j$(nproc)) 2>&1 | grep "^real" | awk '{print $2}')

    if [ $? -eq 0 ]; then
        echo "$config_name,$kernel_id,$commit_id,$build_time" >> $OUTPUT_CSV_FILE
    else
        echo "$config_name,$kernel_id,$commit_id,-1" >> $OUTPUT_CSV_FILE
    fi

done < $SRC_CSV_FILE
