#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(realpath "$SCRIPT_DIR/../../")

usage(){
        echo "Usage: $0 [csv-file] [linux-next path] [syzkaller path] [debian image path] [kernel images path] [output path] [fuzzing-time] [procs] [vm_count] [cpu] [mem]"
    echo
    echo "    csv-file: path to the csv file containing the fuzzing parameters"
    echo "    linux-next path: path to the linux-next repository. Default: \$default_linux_next"
    echo "    syzkaller path: path to the syzkaller repository. Default: \$default_syzkaller"
    echo "    debian image path: path to the debian image. Default: \$default_debian_image"
    echo "    kernel images path: path to the prebuilt kernel images. Default: \$default_kernel_images"
    echo "    output path: path to store the output. Default: \$default_output"
    echo "    fuzzing-time: time for which the fuzzing instance should run. Default: \$default_fuzzing_time"
    echo "    procs: number of processes to run. Default: \$default_procs"
    echo "    vm_count: number of VMs to run. Default: \$default_vm_count"
    echo "    cpu: number of CPUs to use. Default: \$default_cpu"
    echo "    mem: amount of memory to use. Default: \$default_mem"
    echo
    echo "Example:"
    echo "  $0 prebuilt path/to/fuzzing_parameters.csv \\"
    echo "     ../../linux-next ../../syzkaller ../../debian_image \\"
    echo "     ../../kernel_images ./output 12h 2 2 2 2048"

}

default_csv_file="$SCRIPT_DIR/fuzzing_parameters.csv"
default_linux_next="$REPO_ROOT/linux-next"
default_syzkaller="$REPO_ROOT/syzkaller"
default_debian_image="$REPO_ROOT/debian_image"
default_output_path="$SCRIPT_DIR/quickstart_fuzz_output"
default_kernel_images="$REPO_ROOT/kernel_images"
default_fuzzing_time="15m"

default_procs=2
default_vm_count=2
default_cpu=2
default_mem=2048

csv_file="${1:-$default_csv_file}"
csv_file="$(realpath "$csv_file")"

dir_linux_next="${2:-$default_linux_next}"
dir_linux_next="$(realpath "$dir_linux_next")"

syzkaller_path="${3:-$default_syzkaller}"
syzkaller_path="$(realpath "$syzkaller_path")"

debian_image_path="${4:-$default_debian_image}"
debian_image_path="$(realpath "$debian_image_path")"

kernel_images_path="${5:-$default_kernel_images}"
kernel_images_path="$(realpath "$kernel_images_path")"

output_path="${6:-$default_output_path}"
output_path="$(realpath "$output_path")"

fuzzing_time="${7:-$default_fuzzing_time}"
procs="${8:-$default_procs}"
vm_count="${9:-$default_vm_count}"
cpu="${10:-$default_cpu}"
mem="${11:-$default_mem}"

cli_arguments(){
    echo "=========================================================="
    echo "    linux-next path         = $dir_linux_next"
    echo "    syzkaller path          = $syzkaller_path"
    echo "    debian image path       = $debian_image_path"
    echo "    output path             = $output_path"
    echo "    csv path                = $csv_file"
    echo "    kernel images path      = $kernel_images_path"
    echo "    fuzzing time            = $fuzzing_time"
    echo "    log file:               = $log_file"
    echo "    syz-manager configs: "
    echo "      procs                   = $procs"
    echo "      vm_count                = $vm_count"
    echo "      cpu                     = $cpu"
    echo "      mem                     = $mem"
    echo "=========================================================="
}

# Preliminary checks
if [ ! -d "$dir_linux_next" ]; then
    echo "[-] Error: $dir_linux_next doesn't exist"
    usage
    exit 1
fi

if [ ! -d "$syzkaller_path" ]; then
    echo "[-] Error: $syzkaller_path doesn't exist"
    usage
    exit 1
fi

if [ ! -d "$debian_image_path" ]; then
    echo "[-] Error: $debian_image_path doesn't exist"
    usage
    exit 1
fi

if [ ! -f "$csv_file" ]; then
    echo "[-] Error: $csv_file doesn't exist"
    usage
    exit 1
fi

if [ ! -d "$kernel_images_path" ]; then
    echo "[-] Error: $kernel_images_path doesn't exist"
    usage
    exit 1
fi

mkdir -p $output_path
log_file="$output_path/fuzz.log"
exec > >(tee -i "$log_file") 2>&1

cli_arguments

tmp_csv_file=$(mktemp)
head -n 1 $csv_file > $tmp_csv_file

echo "[+] Creating temporary directories for linux-next and debian image to work on them in parallel"
dir_linux_next_default=$(mktemp -d)
rsync -a $dir_linux_next/ $dir_linux_next_default/
dir_linux_next_repaired=$(mktemp -d)
rsync -a $dir_linux_next/ $dir_linux_next_repaired/

debian_image_path_default=$(mktemp -d)
rsync -a $debian_image_path/ $path_debian_image_default/
debian_image_path_repaired=$(mktemp -d)
rsync -a $debian_image_path/ $path_debian_image_repaired/

echo "[+] Succesfully created temporary directories"

# Fuzz kernel images built with default and repaired configuration files, 15 minutes each
bash "$SCRIPT_DIR/fuzzing_experiments.sh" \
    prebuilt default \
    $tmp_csv_file \
    $dir_linux_next_default \
    $syzkaller_path \
    $debian_image_path \
    $kernel_images_path \
    $output_path \
    $fuzzing_time \
    $procs \
    $vm_count \
    $cpu \
    $mem &
bash "$SCRIPT_DIR/fuzzing_experiments.sh" \
    prebuilt repaired \
    $tmp_csv_file \
    $dir_linux_next_repaired \
    $syzkaller_path \
    $debian_image_path \
    $kernel_images_path \
    $output_path \
    $fuzzing_time \
    $procs \
    $vm_count \
    $cpu \
    $mem &

wait

echo "[+] Fuzzing experiments completed"
echo "[+] Results are stored in $output_path"

# Cleanup
rm -rf $tmp_csv_file
rm -rf $dir_linux_next_default
rm -rf $dir_linux_next_repaired
rm -rf $debian_image_path_default
rm -rf $debian_image_path_repaired
