#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Global definitions
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../")"

################################################################################
# Usage & argument parsing
################################################################################

usage() {
    echo "Usage: $0 [linux-next path] [syzkaller path] [debian image path] [output path] [csv path]"
    echo "Usage: $0 [experiment_type] [fuzz_type] [csv-file] [linux-next path] [syzkaller path]" \
         "[debian image path] [output path] [fuzzing-time] [procs] [vm_count] [cpu] [mem]"

    echo "    experiment_type: default | repaired"
    echo "    fuzz_type: prebuilt | full"
    echo "    csv-file: path to the csv file containing the fuzzing parameters"
    echo "    linux-next path: path to the linux-next repository. Default: $default_linux_next"
    echo "    syzkaller path: path to the syzkaller repository. Default: $default_syzkaller"
    echo "    debian image path: path to the debian image. Default: $default_debian_image"
    echo "    output path: path to store the output of the experiments. Default: $default_path_output"
    echo "    fuzzing-time: time for which the fuzzing instance should run. Default: $default_fuzzing_time"
    echo "    procs: number of processes to run. Default: $default_procs"
    echo "    vm_count: number of VMs to run. Default: $default_vm_count"
    echo "    cpu: number of CPUs to use. Default: $default_cpu"
    echo "    mem: amount of memory to use. Default: $default_mem"
    echo "Example: $0 prebuilt default experiments/fuzzing/fuzzing_parameters.csv" \
    "../../linux-next ../../syzkaller ../../debian_image ./output 12h 2 2 2 2048"
    exit 1
}

cli_arguments() {
    # This function prints the CLI arguments in a readable format
    echo "=========================================================="
    echo "Experiment type: $experiment_type"
    echo "Fuzz type: $fuzz_type"
    echo "CSV file: $csv_file"
    echo "linux-next path: $dir_linux_next"
    echo "syzkaller path: $syzkaller_path"
    echo "Debian images path: $debian_image_path"
    echo "Kernel images path: $kernel_images_path"
    echo "Output path: $output_path"
    echo "Fuzzing time: $fuzzing_time"
    echo "syz-manager params:"
    echo "  Procs: $procs"
    echo "  VM count: $vm_count"
    echo "  CPU: $cpu"
    echo "  Memory: $mem"
    echo "=========================================================="
}

default_experiment_type="default"
default_fuzz_type="prebuilt"
default_csv_file="$SCRIPT_DIR/fuzzing_parameters.csv"
default_linux_next="$REPO_ROOT/linux-next"
default_syzkaller="$REPO_ROOT/syzkaller"
default_debian_image="$REPO_ROOT/debian_image"
default_kernel_images="$REPO_ROOT/kernel_images"
default_output="$SCRIPT_DIR/fuzz_output"
default_fuzzing_time="12h"

# syzkaller related defaults
# Note: We conducted our experiments on a server with 512GB RAM and 256 cores
# Therefore, we set the default values to 8 procs, 8 VMs, 8 CPUs, and 4098MB RAM
# You can adjust these values based on your server's resources
default_procs=2
default_vm_count=2
default_cpu=2
default_mem=2048

experiment_type="${2:-$default_experiment_type}"
fuzz_type="${1:-$default_fuzz_type}"

csv_file="${3:-$default_csv_file}"
csv_file="$(realpath "$csv_file")"

dir_linux_next="${4:-$default_linux_next}"
dir_linux_next="$(realpath "$dir_linux_next")"

syzkaller_path="${5:-$default_syzkaller}"
syzkaller_path="$(realpath "$syzkaller_path")"

debian_image_path="${6:-$default_debian_image}"
debian_image_path="$(realpath "$debian_image_path")"

kernel_images_path="${7:-$default_kernel_images}"
kernel_images_path="$(realpath "$kernel_images_path")"

output_path="${8:-$default_output}"
output_path="$(realpath "$output_path")"

fuzzing_time="${9:-$default_fuzzing_time}"
procs="${10:-$default_procs}"
vm_count="${11:-$default_vm_count}"
cpu="${12:-$default_cpu}"
mem="${13:-$default_mem}"

# Create a unique output directory based on the current time
unix_time="$(date +%s)"
output_path="$output_path/$unix_time"
mkdir -p "$output_path"

################################################################################
# Preliminary checks
################################################################################

if [[ "$experiment_type" != "repaired" && "$experiment_type" != "default" ]]; then
    echo "[!] <experiment_type> must be one of: repaired | default"
    usage
    exit 1
fi

if [[ "$fuzz_type" != "prebuilt" && "$fuzz_type" != "full" ]]; then
    echo "[!] <fuzz_type> must be one of: prebuilt | full"
    usage
    exit 1
fi

if [[ ! -f "$csv_file" ]]; then
    echo "[-] CSV file does not exist: $csv_file"
    usage
    exit 1
fi

if [[ ! -d "$dir_linux_next" ]]; then
    echo "[-] linux-next directory does not exist: $dir_linux_next"
    usage
    exit 1
fi

if [[ ! -d "$syzkaller_path" ]]; then
    echo "[-] syzkaller directory does not exist: $syzkaller_path"
    usage
    exit 1
fi

if [[ ! -d "$debian_image_path" ]]; then
    echo "[-] Debian images directory does not exist: $debian_image_path"
    usage
    exit 1
fi

# Check if klocalizer binary exists
if [ ! -x "$(command -v klocalizer)" ]; then
    echo "[-] klocalizer binary not found"
    echo "[-] Please install klocalizer with: pipx install kmax"
    exit 1
fi

# Check if /bin/syz-manager binary exists in syzkaller path
if [ ! -x "$syzkaller_path/bin/syz-manager" ]; then
    echo "[-] syz-manager binary not found"
    echo "[*] Building syzkaller..."
    (cd "$syzkaller_path" && make) || {
        echo "[-] Failed to build syzkaller"
        exit 1
    }
    echo "[+] syzkaller built successfully"
fi

if [[ "$fuzz_type == "prebuilt" ]]; then
    output_path="${output_path}_prebuilt"
elif [[ "$fuzz_type == "full" ]]; then
    output_path="${output_path}_full"
fi

cli_arguments

################################################################################
# Prepare output directory and logging
################################################################################

log_file="$output_path/main_script_logs.log"

# All output from the script is tee'd to main_script_logs.log
exec > >(tee -i "$log_file") 2>&1
echo "[*] Logs saved in $log_file"

################################################################################
# Additional directories depending on experiment type
################################################################################

# Paths to original and repaired syzbot config files
syzbot_config_files_path="$REPO_ROOT/configuration_files/syzbot_configuration_files"
repaired_config_files_path="$REPO_ROOT/configuration_files/repaired_configuration_files"

################################################################################
# Helper functions
################################################################################

function find_free_port() {
    local start_port="$1"
    local port="$start_port"

    # You can add a max increment if desired
    while ss -tuln 2>/dev/null | grep -q ":$port\b"; do
        ((port++))
    done

    echo "$port"
}

function clean_linux_next_repo() {
    echo "[+] Cleaning the linux-next repo..."
    git clean -dfx || { echo "[-] git clean failed"; exit 1; }

    echo "[+] Resetting the repo to origin/master..."
    git reset --hard origin/master || { echo "[-] git reset failed"; exit 1; }
}

function checkout_git_tag() {
    local git_tag="$1"
    echo "[+] Checking out to tag $git_tag..."
    git checkout -f "$git_tag" || {
        echo "[-] git checkout failed for tag $git_tag"
        exit 1
    }
}

function build_linux_kernel() {
    local config_file="$1"
    local kernel_dir="$2"
    local config_mode="$3"  # "default" or "repaired"

    echo "[+] make defconfig..."
    make CC=$(which gcc) defconfig

    if [[ "$config_mode" == "default" ]]; then
        echo "[+] Copying syzbot config file -> .config"
        cp "$config_file" "$kernel_dir/.config"
    else
        echo "[+] Copying repaired config file -> .config"
        cp "$config_file" "$kernel_dir/.config"
    fi

    echo "[+] make kvm_guest.config..."
    make CC=$(which gcc) kvm_guest.config

    echo "[+] Enabling syzkaller-related kernel configs via scripts/config..."
    ./scripts/config --enable CONFIG_KCOV \
                     --enable CONFIG_DEBUG_INFO \
                     --enable CONFIG_DEBUG_INFO_DWARF4 \
                     --disable CONFIG_DEBUG_INFO_BTF \
                     --enable CONFIG_KASAN \
                     --enable CONFIG_KASAN_INLINE \
                     --enable CONFIG_CONFIGFS_FS \
                     --enable CONFIG_SECURITYFS \
                     --enable CONFIG_CMDLINE_BOOL \
                     --set-val CONFIG_CMDLINE "\"net.ifnames=0\""

    echo "[+] make olddefconfig..."
    make CC=$(which gcc) olddefconfig

    echo "[+] Compiling the kernel..."
    make CC=$(which gcc) -j"$(nproc)" || {
        echo "[-] Kernel compilation failed"
        exit 1
    }

    # Optional check for bzImage
    if [[ ! -f "$kernel_dir/arch/x86/boot/bzImage" ]]; then
        echo "[-] bzImage not found after compilation. Build must have failed."
        exit 1
    fi
    echo "[+] Kernel compiled successfully!"
}

function run_syzkaller_fuzz() {
    local syz_cfg="$1"
    local fuzzing_log="$2"
    local fuzzing_time="$3"

    echo "[*] Running syzkaller fuzzing with config: $syz_cfg"
    # 12h fuzzing
    timeout $fuzzing_time "$syzkaller_path/bin/syz-manager" \
        -config="$syz_cfg" 2>&1 | tee "$fuzzing_log" || true
    local exit_status_timeout="${PIPESTATUS[0]}"

    if [[ "$exit_status_timeout" -eq 0 ]]; then
        echo "[+] Fuzzing instance completed successfully"
    elif [[ "$exit_status_timeout" -eq 124 ]]; then
        echo "[+] Fuzzing instance timed out after 12 hours"
    elif [[ "$exit_status_timeout" -ge 128 ]]; then
        local signal_number="$((exit_status_timeout - 128))"
        echo "[-] Fuzzing instance terminated by signal ${signal_number}"
    else
        echo "[-] Fuzzing instance exited with error code $exit_status_timeout"
    fi

    # Added this so that the script does not exist as timeout returns 124
    return 0
}

function run_klocalizer() {
    local kernel_src="$1"
    local config_file="$2"
    local repair_commit_hash="$3"
    local output_folder="$4"
    local repaired_config_file="$5"

    # Change into the kernel source directory or exit if it fails
    pushd "$kernel_src" || {
        echo "Error: Could not enter directory '$kernel_src'!"
        return 1
    }
    diff_file="$output_folder/${repair_commit_hash}.diff"
    git show "$repair_commit_hash" > "$diff_file"

    # Run klocalizer with the specified arguments/defines
    klocalizer -v \
        -a x86_64 \
        --repair "$config_file" \
        --include-mutex "$diff_file" \
        --formulas "$output_folder/formulacache" \
        --coverage-report "$output_folder/coverage_report.json" \
        --define CONFIG_KCOV \
        --define CONFIG_DEBUG_INFO_DWARF4 \
        --define CONFIG_KASAN \
        --define CONFIG_KASAN_INLINE \
        --define CONFIG_CONFIGFS_FS \
        --define CONFIG_SECURITYFS 2>&1 | tee "$output_folder/klocalizer.log"

    # Check for 0-x86_64.config, move it to $output_folder if present
    if [[ -f "0-x86_64.config" ]]; then
        mv "0-x86_64.config" "$repaired_config_file"
    else
        echo "0-x86_64.config not found"
    fi

    # Return to the original directory
    popd || return 1

    # Return $repaired_config_file if it exists
    if [[ -f "$repaired_config_file" ]]; then
        echo "$repaired_config_file"
    else
        return 1
    fi
}

function utilize_artifacts() {
    # This function is only used in 'prebuilt' fuzzing mode
    # It first extracts the provided artifacts and gets bzImage and vmlinux
    # files, and then places them in the kernel source directory for syzkaller
    # to use.

    local artifacts_path="$1"
    local kernel_src="$2"

    # Ensure the artifacts path exists
    if [ ! -f "$artifacts_path" ]; then
        echo "Error: Provided artifacts path does not exist."
        return 1
    fi

    # Extract the artifacts
    7z x "$artifacts_path" -o"$kernel_src" || {
        echo "Error: Unable to extract artifacts."
        return 1
    }

    echo "[+] Extracted $artifacts_path to $kernel_src"

    # Move the bzImage and vmlinux files to the kernel source directory
    # for syzkaller to use
    mv "$kernel_src"/bzImage "$kernel_src"/arch/x86/boot/bzImage

    echo "[+] Artifacts placed successfully in $kernel_src."

    return 0
}

################################################################################
# Main fuzzing loop
################################################################################

# We pick a random initial port. If it's used, find_free_port will increment
syzkaller_port=$(shuf -i 1024-65535 -n 1)
syzkaller_port="$(find_free_port "$syzkaller_port")"

echo "[*] Initial syzkaller port: $syzkaller_port"
echo "[*] Starting fuzzing experiments..."

while IFS=, read -r commit_hash syzbot_config_name git_tag repaired_config_name default_artifact repaired_artifact; do
    # Skip empty lines or lines with missing fields
    if [[ -z "$commit_hash" || -z "$syzbot_config_name" || -z "$git_tag" ]]; then
        echo "[!] Skipping malformed CSV line: $commit_hash,$syzbot_config_name,$git_tag,$repaired_config_name"
        continue
    fi

    echo "=========================================================="
    echo "[+] Processing CSV line:"
    echo "    Commit hash         = $commit_hash"
    echo "    Syzbot config name  = $syzbot_config_name"
    echo "    Git tag             = $git_tag"
    echo "    Repaired config     = $repaired_config_name"
    echo "    Current syzkaller port = $syzkaller_port"
    echo "=========================================================="

    cd "$dir_linux_next" || exit 1
    clean_linux_next_repo
    checkout_git_tag "$git_tag"

    if [[ "$experiment_type" == "default" ]]; then
        output_path_instance="${output_path}/default/${commit_hash}"
        mkdir -p "$output_path_instance"
    elif [[ "$experiment_type" == "repaired" ]]; then
        output_path_instance="${output_path}/repaired/${commit_hash}"
        mkdir -p "$output_path_instance"
    fi

    if [[ "$fuzz_type" == "full" ]]; then
        repaired_config_file=""

        if [[ "$experiment_type" == "repaired" ]]; then
            # Run klocalizer to generate a repaired config file
            echo "[*] Running klocalizer for commit: $commit_hash"
            repaired_config_file="${output_path_instance}/repaired_${commit_hash}.config"
            run_klocalizer "$dir_linux_next" "$syzbot_config_files_path/$syzbot_config_name" "$commit_hash" "$output_path_instance" "$repaired_config_file"
            if [[ -z "$repaired_config_file" ]]; then
                echo "[-] klocalizer failed for commit: $commit_hash"
                continue
            fi
        fi

        local_config_file=$repaired_config_file

        # Validate the existence of the config file we want to copy
        if [[ "$experiment_type" == "default" ]]; then
            local_config_file="$syzbot_config_files_path/$syzbot_config_name"
            if [[ ! -f "$local_config_file" ]]; then
                echo "[-] Syzbot config file does not exist: $local_config_file"
                exit 1
            fi
        fi

        # Build the kernel with the desired config
        build_linux_kernel "$local_config_file" "$dir_linux_next" "$experiment_type"
    fi

    if [[ "$fuzz_type" == "prebuilt" ]]; then
        # Utilize the provided artifacts
        if [[ "$experiment_type" == "default" ]]; then
            artifact="$kernel_images_path/default/$default_artifact"
        elif [[ "$experiment_type" == "repaired" ]]; then
            artifact="$kernel_images_path/repaired/$repaired_artifact"
        fi
        utilize_artifacts "$artifact" "$dir_linux_next"
    fi

    # Prepare syzkaller workdir
    workdir_name="$output_path_instance/fuzzing_results/syzkaller_workdir_${syzbot_config_name}_${commit_hash}"
    mkdir -p "$workdir_name"
    echo "[+] Created syzkaller workdir: $workdir_name"

    # Create or overwrite syzkaller main config file
    syz_cfg="$syzkaller_path/$(date +%s).cfg"
    cat > "$syz_cfg" <<EOF
{
  "target": "linux/amd64",
  "http": "127.0.0.1:$syzkaller_port",
  "workdir": "$workdir_name",
  "kernel_obj": "$dir_linux_next",
  "image": "$debian_image_path/bullseye.img",
  "sshkey": "$debian_image_path/bullseye.id_rsa",
  "syzkaller": "$syzkaller_path",
  "procs": $procs,
  "type": "qemu",
  "vm": {
    "count": $vm_count,
    "kernel": "$dir_linux_next/arch/x86/boot/bzImage",
    "cpu": $cpu,
    "mem": $mem,
    "cmdline": "net.ifnames=0",
    "qemu_args": "-enable-kvm -cpu qemu64"
  }
}
EOF

    # Prepare the fuzzing log path
    mkdir -p "$output_path_instance/fuzzing_instance_logs/"
    fuzzing_instance_log_path="$output_path_instance/fuzzing_instance_logs/syzkaller_terminal_${syzbot_config_name}_${commit_hash}.log"

    # Run fuzzing
    echo "syz config path: $syz_cfg"
    echo "fuzzing_instance_log_path: $fuzzing_instance_log_path"
    echo "fuzzing_time $fuzzing_time"
    run_syzkaller_fuzz "$syz_cfg" "$fuzzing_instance_log_path" "$fuzzing_time"

    # Move to the next port if needed
    syzkaller_port="$((syzkaller_port + 1))"
    syzkaller_port="$(find_free_port "$syzkaller_port")"

    echo "[+] Done with commit: $commit_hash"
    echo "=========================================================="
done < "$csv_file"

echo "[*] All fuzzing done!"
echo "[*] Final logs: $log_file"
