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
    echo "[!] Usage: $0 <experiment_type> <csv-file> <path to linux-next> <path to syzkaller>"
    echo "           <path to debian image> <path to output folder> <fuzzing-time>"
    echo "[*] Example: $0 default experiments/fuzzing/fuzzing_parameters.csv linux-next syzkaller debian_image experiments/fuzzing/output 12h"
    echo "    where all paths except syzkaller_path are relative to \$REPO_ROOT."
    exit 9
}

if [[ $# -ne 7 ]]; then
    usage
fi

experiment_type="$1"
csv_file="$(realpath $2)"
dir_linux_next="$(realpath $3)"
syzkaller_path="$(realpath $4)"
debian_image_path="$(realpath $5)"
output_path="$(realpath $6)"
fuzzing_time="$7"

# Create a unique output directory based on the current time
unix_time="$(date +%s)"
output_path="$output_path/$unix_time"
mkdir -p "$output_path"

if [[ "$experiment_type" != "repaired" && "$experiment_type" != "default" ]]; then
    echo "[!] <experiment_type> must be one of: repaired | default"
    exit 1
fi

################################################################################
# Preliminary checks
################################################################################

if [[ ! -f "$csv_file" ]]; then
    echo "[-] CSV file does not exist: $csv_file"
    exit 1
fi

if [[ ! -d "$dir_linux_next" ]]; then
    echo "[-] linux-next directory does not exist: $dir_linux_next"
    exit 1
fi

if [[ ! -d "$syzkaller_path" ]]; then
    echo "[-] syzkaller directory does not exist: $syzkaller_path"
    exit 1
fi

if [[ ! -d "$debian_image_path" ]]; then
    echo "[-] Debian images directory does not exist: $debian_image_path"
    exit 1
fi

echo "[+] Experiment type: $experiment_type"
echo "[+] CSV file: $csv_file"
echo "[+] linux-next path: $dir_linux_next"
echo "[+] syzkaller path: $syzkaller_path"
echo "[+] Debian images path: $debian_image_path"
echo "[+] Output path: $output_path"

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

if [[ "$experiment_type" == "repaired" ]]; then
    mkdir -p "$output_path/coverage_commit_diff_files"
    mkdir -p "$output_path/coverage_commit_koverage_files"
    mkdir -p "$output_path/coverage_commit_configuration_files"
fi

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
        -config="$syz_cfg" 2>&1 | tee "$fuzzing_log"
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
}

################################################################################
# Main fuzzing loop
################################################################################

# We pick an initial port. If it's used, find_free_port will increment
syzkaller_port=$(shuf -i 1024-65535 -n 1)
syzkaller_port="$(find_free_port "$syzkaller_port")"

echo "[*] Initial syzkaller port: $syzkaller_port"
echo "[*] Starting fuzzing experiments..."

while IFS=, read -r commit_hash syzbot_config_name git_tag repaired_config_name; do
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

    # Validate the existence of the config file we want to copy
    local_config_file=""
    if [[ "$experiment_type" == "default" ]]; then
        local_config_file="$syzbot_config_files_path/$syzbot_config_name"
        if [[ ! -f "$local_config_file" ]]; then
            echo "[-] Syzbot config file does not exist: $local_config_file"
            exit 1
        fi
    else
        local_config_file="$repaired_config_files_path/$repaired_config_name"
        if [[ ! -f "$local_config_file" ]]; then
            echo "[-] Repaired config file does not exist: $local_config_file"
            exit 1
        fi
    fi

    # Build the kernel with the desired config
    build_linux_kernel "$local_config_file" "$dir_linux_next" "$experiment_type"

    # Prepare syzkaller workdir
    workdir_name="$output_path/fuzzing_results/syzkaller_workdir_${syzbot_config_name}_${commit_hash}"
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
  "procs": 8,
  "type": "qemu",
  "vm": {
    "count": 8,
    "kernel": "$dir_linux_next/arch/x86/boot/bzImage",
    "cpu": 8,
    "mem": 4098,
    "cmdline": "net.ifnames=0",
    "qemu_args": "-cpu qemu64"
  }
}
EOF

    # Prepare the fuzzing log path
    mkdir -p "$output_path/fuzzing_instance_logs/"
    fuzzing_instance_log_path="$output_path/fuzzing_instance_logs/syzkaller_terminal_${syzbot_config_name}_${commit_hash}.log"

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
