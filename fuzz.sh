#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

usage(){
    echo "Usage: $0 [linux-next path] [syzkaller path] [debian image path] [output path]" \
         "[csv path] [kernel images path] [fuzzing time]"
    echo "    linux-next path: path to the linux-next repository. Default: $default_linux_next"
    echo "    syzkaller path: path to the syzkaller repository. Default: $default_syzkaller"
    echo "    debian image path: path to the debian image. Default: $default_debian_image"
    echo "    output path: path to store the output of the experiments. Default: $default_path_output"
    echo "    csv path: path to the csv file containing the fuzzing parameters. Default: $default_path_csv"
    echo "    kernel images path: path to the kernel images. Default: $default_path_kernel_images"
    echo "    fuzzing time: time to run the fuzzing experiments. Default: $default_fuzzing_time"
}

default_linux_next="$SCRIPT_DIR/linux-next"
default_syzkaller="$SCRIPT_DIR/syzkaller"
default_debian_image="$SCRIPT_DIR/debian_image"
default_path_output="$SCRIPT_DIR/quickstart_fuzz_output"
default_path_csv="$SCRIPT_DIR/experiments/fuzzing/fuzzing_parameters.csv"
default_path_kernel_images="$SCRIPT_DIR/kernel_images"
default_fuzzing_time="15m"

path_linux_next=${1:-$default_linux_next}
path_linux_next=$(realpath $path_linux_next)

path_syzkaller=${2:-$default_syzkaller}
path_syzkaller=$(realpath $path_syzkaller)

path_debian_image=${3:-$default_debian_image}
path_debian_image=$(realpath $path_debian_image)

path_output=${4:-$default_path_output}

path_csv=${5:-$default_path_csv}
path_csv=$(realpath $path_csv)

path_kernel_images=${6:-$default_path_kernel_images}
path_kernel_images=$(realpath $path_kernel_images)

fuzzing_time=${7:-$default_fuzzing_time}

echo "=========================================================="
echo "[+] Got CLI Arguments:"
echo "    linux-next path         = $path_linux_next"
echo "    syzkaller path          = $path_syzkaller"
echo "    debian image path       = $path_debian_image"
echo "    output path             = $path_output"
echo "    csv path                = $path_csv"
echo "    kernel images path      = $path_kernel_images"
echo "    fuzzing time            = $fuzzing_time"
echo "=========================================================="

# Preliminary checks
if [ ! -d "$path_linux_next" ]; then
    echo "[-] Error: $path_linux_next doesn't exist"
    usage
    exit 1
fi

if [ ! -d "$path_syzkaller" ]; then
    echo "[-] Error: $path_syzkaller doesn't exist"
    usage
    exit 1
fi

if [ ! -d "$path_debian_image" ]; then
    echo "[-] Error: $path_debian_image doesn't exist"
    usage
    exit 1
fi

if [ ! -f "$path_csv" ]; then
    echo "[-] Error: $path_csv doesn't exist"
    usage
    exit 1
fi

if [ ! -d "$path_kernel_images" ]; then
    echo "[-] Error: $path_kernel_images doesn't exist"
    usage
    exit 1
fi

path_output_default="$path_output/default"
path_output_repaired="$path_output/repaired"
mkdir -p $path_output_default
mkdir -p $path_output_repaired

tmp_path_csv=$(mktemp)
head -n 1 $path_csv > $tmp_path_csv

echo "[+] Creating temporary directories for linux-next and debian image to work on them in parallel"
path_linux_next_default=$(mktemp -d)
rsync -a $path_linux_next/ $path_linux_next_default/
path_linux_next_repaired=$(mktemp -d)
rsync -a $path_linux_next/ $path_linux_next_repaired/

path_debian_image_default=$(mktemp -d)
rsync -a $path_debian_image/ $path_debian_image_default/
path_debian_image_repaired=$(mktemp -d)
rsync -a $path_debian_image/ $path_debian_image_repaired/

echo "[+] Succesfully created temporary directories"

# Fuzz kernel images built with default and repaired configuration files, 15 minutes each
bash "$SCRIPT_DIR/experiments/fuzzing/fuzzing_experiments.sh" prebuilt default $tmp_path_csv $path_linux_next_default $path_syzkaller $path_debian_image $path_kernel_images $path_output_default $fuzzing_time &
bash "$SCRIPT_DIR/experiments/fuzzing/fuzzing_experiments.sh" prebuilt repaired $tmp_path_csv $path_linux_next_repaired $path_syzkaller $path_debian_image $path_kernel_images $path_output_repaired $fuzzing_time &

wait

echo "[+] Fuzzing experiments completed"
echo "[+] Results are stored in $path_output_default and $path_output_repaired"

# Cleanup
rm -rf $tmp_path_csv
rm -rf $path_linux_next_default
rm -rf $path_linux_next_repaired
rm -rf $path_debian_image_default
rm -rf $path_debian_image_repaired
