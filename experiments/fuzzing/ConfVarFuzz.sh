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
    echo "[!] Usage: $0 <experiment_type> <fuzz_type> <csv-file> <path to linux-next> <path to syzkaller>"
    echo "           <path to debian image> <path to output folder> <fuzzing-time>"
    echo "[*] Example: $0 default experiments/fuzzing/fuzzing_parameters.csv linux-next syzkaller debian_image experiments/fuzzing/output 12h"
    echo "    where all paths except syzkaller_path are relative to \$REPO_ROOT."
    exit 9
}

if [[ $# -ne 8 ]]; then
    usage
fi

experiment_type="$1"
fuzz_type="$2"
csv_file="$(realpath $3)"
dir_linux_next="$(realpath $4)"
syzkaller_path="$(realpath $5)"
debian_image_path="$(realpath $6)"
output_path="$(realpath $7)"
fuzzing_time="$8"

# Create a unique output directory based on the current time
unix_time="$(date +%s)"
output_path="$output_path/$unix_time"
mkdir -p "$output_path"

################################################################################
# Preliminary checks
################################################################################

if [[ "$experiment_type" != "repaired" && "$experiment_type" != "default" ]]; then
    echo "[!] <experiment_type> must be one of: repaired | default"
    exit 1
fi

if [[ "$fuzz_type" != "quickstart" && "$fuzz_type" != "prebuilt" && "$fuzz_type" != "full" ]]; then
    echo "[!] <fuzz_type> must be one of: quickstart | prebuilt | full"
    exit 1
fi

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

# Check if klocalizer binary exists
if [ -x "$(command -v klocalizer)" ]; then
    echo "[+] klocalizer binary found"
else
    echo "[-] klocalizer binary not found"
    echo "[-] Please install klocalizer with: pipx install kmax"
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
    timeout $fuzzing_time "$REPO_ROOT/$syzkaller_path/bin/syz-manager" \
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


# get_commits_for_previous_date() {
#     local date="$1"  # Date in YYYY-MM-DD format
#     local kernel_src="$2"  # Path to the Linux kernel source directory
#     local commit_hashes=()
#
#     if [ ! -d "$kernel_src/.git" ]; then
#         echo "Error: $kernel_src is not a valid Git repository."
#         return 1
#     fi
#
#     # Calculate the previous date
#     local previous_date
#     previous_date=$(date -I -d "$date - 1 day")
#     if [ $? -ne 0 ]; then
#         echo "Error: Invalid date format or date calculation failed."
#         return 1
#     fi
#
#     echo "Searching for all commits on: $previous_date in $kernel_src"
#
#     # Change to the specified kernel source directory
#     pushd "$kernel_src" > /dev/null
#
#     # Define start and end times for the previous day
#     local day_start="${previous_date}T00:00:00"
#     local day_end="${previous_date}T23:59:59"
#
#     # Get all commits for the previous date
#     commits=$(git log --since="$day_start" --until="$day_end" --pretty=format:"%H")
#
#     if [ -z "$commits" ]; then
#         echo "No commits found on $previous_date."
#     else
#         echo "Commits found on $previous_date:"
#         echo "$commits"
#         commit_hashes=($commits)
#     fi
#
#     # Return to the original directory
#     popd > /dev/null
#
#     # Return the array by echoing its elements (space-separated)
#     echo "${commit_hashes[@]}"
# }
# get_diff_of_random_commit() {
#     local date="$1"  # Date in YYYY-MM-DD format
#     local kernel_src="$2"  # Path to the Linux kernel source directory
#     local output_folder="$3"  # Path to the output folder
#     local output_file="random_commit.diff"  # Default name for the diff file
#
#     # Ensure the output folder exists
#     if [ ! -d "$output_folder" ]; then
#         mkdir -p "$output_folder" || {
#             echo "Error: Unable to create output folder $output_folder."
#             return 1
#         }
#     fi
#
#     # Get commits for the previous day
#     commit_hashes=($(get_commits_for_previous_date "$date" "$kernel_src"))
#
#     if [ ${#commit_hashes[@]} -eq 0 ]; then
#         echo "No commits to process."
#         return 1
#     fi
#
#     # Shuffle the array
#     shuffled_commits=($(shuf -e "${commit_hashes[@]}"))
#
#     # Select a random commit
#     local random_commit="${shuffled_commits[0]}"
#     echo "Randomly selected commit: $random_commit"
#
#     # Change to the kernel source directory to generate the diff
#     pushd "$kernel_src" > /dev/null
#     git show "$random_commit" > "$output_folder/$output_file"
#     popd > /dev/null
#
#     local diff_path="$output_folder/$output_file"
#     echo "Diff saved to: $diff_path"
#     echo "$diff_path"
# }
#
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
    # This function is only used in 'quickstart' and 'prebuilt' fuzzing modes
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

    # Move the bzImage and vmlinux files to the kernel source directory
    # for syzkaller to use
    mv "$kernel_src"/bzImage "$kernel_src"/arch/x86/boot/bzImage
    mv "$kernel_src"/vmlinux "$kernel_src"/vmlinux

    echo "Artifacts utilized successfully."

    return 0
}

################################################################################
# Main fuzzing loop
################################################################################

# We pick an initial port. If it's used, find_free_port will increment
syzkaller_port=56700
syzkaller_port="$(find_free_port "$syzkaller_port")"

echo "[*] Initial syzkaller port: $syzkaller_port"
echo "[*] Starting fuzzing experiments..."

while IFS=, read -r commit_hash syzbot_config_name git_tag repaired_config_name artifact; do
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

    if [[ "$fuzz_type" == "full" ]]; then
        repaired_config_file=""

        if [[ "$experiment_type" == "repaired" ]]; then
            output_path="${output_path}/repaired/${commit_hash}"
            mkdir -p "$output_path"

            # Run klocalizer to generate a repaired config file
            echo "[*] Running klocalizer for commit: $commit_hash"
            repaired_config_file="${output_path}/repaired_${commit_hash}.config"
            run_klocalizer "$dir_linux_next" "$syzbot_config_files_path/$syzbot_config_name" "$commit_hash" "$output_path" "$repaired_config_file"
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

    if [[ "$fuzz_type" == "quickstart" || "$fuzz_type" == "prebuilt" ]]; then
        # Utilize the provided artifacts
        utilize_artifacts "$artifact" "$dir_linux_next"
    fi

    # Prepare syzkaller workdir
    workdir_name="$output_path/fuzzing_results/syzkaller_workdir_${syzbot_config_name}_${commit_hash}"
    mkdir -p "$workdir_name"
    echo "[+] Created syzkaller workdir: $workdir_name"

    # Create or overwrite syzkaller main config file
    syz_cfg="$REPO_ROOT/$syzkaller_path/my.cfg"
    cat > "$syz_cfg" <<EOF
{
  "target": "linux/amd64",
  "http": "127.0.0.1:$syzkaller_port",
  "workdir": "$workdir_name",
  "kernel_obj": "$dir_linux_next",
  "image": "$debian_image_path/bullseye.img",
  "sshkey": "$debian_image_path/bullseye.id_rsa",
  "syzkaller": "$REPO_ROOT/$syzkaller_path",
  "procs": 8,
  "type": "qemu",
  "vm": {
    "count": 8,
    "kernel": "$dir_linux_next/arch/x86/boot/bzImage",
    "cpu": 8,
    "mem": 4098,
    "cmdline": "net.ifnames=0",
    "qemu_args": "-enable-kvm -cpu qemu64"
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
