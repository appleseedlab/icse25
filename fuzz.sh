#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check if the number of arguments is correct
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <path_linux_next> <path_syzkaller> <path_debian_image> <path_output>"
    exit 1
fi

path_linux_next=$(realpath $1)
path_syzkaller=$(realpath $2)
path_debian_image=$(realpath $3)
path_output=$(realpath $4)

echo "=========================================================="
echo "[+] Got CLI Arguments:"
echo "    linux-next path         = $path_linux_next"
echo "    syzkaller path          = $path_syzkaller"
echo "    debian image path       = $path_debian_image"
echo "    output path             = $path_output"
echo "=========================================================="

# Preliminary checks
if [ ! -d "$path_linux_next" ]; then
    echo "[-] Error: $path_linux_next doesn't exist"
    exit 1
fi

if [ ! -d "$path_syzkaller" ]; then
    echo "[-] Error: $path_syzkaller doesn't exist"
    exit 1
fi

if [ ! -d "$path_debian_image" ]; then
    echo "[-] Error: $path_debian_image doesn't exist"
    exit 1
fi

path_output_default="$path_output/default"
path_output_repaired="$path_output/repaired"
mkdir -p $path_output_default
mkdir -p $path_output_repaired

path_csv="$SCRIPT_DIR/fuzz.csv"

echo "[+] Creating temporary directories for linux-next and debian image to work on them in parallel"
path_linux_next_default=$(mktemp -d)
cp -r $path_linux_next/* $path_linux_next_default
path_linux_next_repaired=$(mktemp -d)
cp -r $path_linux_next/* $path_linux_next_repaired

path_debian_image_default=$(mktemp -d)
cp -r $path_debian_image/* $path_debian_image_default
path_debian_image_repaired=$(mktemp -d)
cp -r $path_debian_image/* $path_debian_image_repaired

echo "[+] Succesfully created temporary directories"

# Fuzz kernel images built with default and repaired configuration files, 15 minutes each
bash "$SCRIPT_DIR/experiments/fuzzing/fuzzing_experiments.sh" default $path_csv $path_linux_next_default $path_syzkaller $path_debian_image $path_output_default 15m &
bash "$SCRIPT_DIR/experiments/fuzzing/fuzzing_experiments.sh" repaired $path_csv $path_linux_next_repaired $path_syzkaller $path_debian_image $path_output_repaired 15m &

wait
