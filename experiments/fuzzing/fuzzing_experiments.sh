set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../")"

# check experiment type
if [ "$1" != "repaired" ] && [ "$1" != "default" ]; then
    echo "[!] Please specify the experiment type: repaired or default"
    exit 1
fi

if [ "$#" -ne 7 ]; then
    echo "[!] Usage: ./program <experiment_type> <csv-file> <path to linux-next> <path to syzkaller>
    <path to debian image> <path to syzbot configs> <path to output folder>"
    echo "[*] Example Usage: ./program default repairer_script/fuzzing_parameters.csv " \
        "~/linux-next/ ~/syzkaller/ ~/debian_images/" \
        "camera_ready/configuration_files/syzbot_configuration_files ~/output/"
    echo "[-] Exiting..."
    exit 9
fi

experiment_type=$1
csv_file=$REPO_ROOT/$2
dir_linux_next=$REPO_ROOT/$3
syzkaller_path=$4
debian_image_path=$REPO_ROOT/$5
syzbot_config_files_path=$REPO_ROOT/$6
output_path=$SCRIPT_DIR/$7

repaired_config_files_path="$REPO_ROOT/camera_ready/configuration_files/repaired_configuration_files"

unix_time=$(date +%s)
output_path=$output_path/$unix_time
mkdir -p $output_path
log_file=$output_path/main_script_logs.log

exec > >(tee -i "$log_file") 2>&1

if [ "$experiment_type" == "repaired" ]; then
    # Path to saved diff files that are used
    output_of_diff=$output_path/coverage_commit_diff_files/;
    mkdir -p $output_of_diff

    # Path to saved koverage result files
    output_of_koverage=$output_path/coverage_commit_koverage_files/;
    mkdir -p $output_of_koverage

    # Path to saved repaired koverage result files
    output_of_repaired_koverage_path=$output_path/coverage_commit_configuration_files/;
    mkdir -p $output_of_repaired_koverage_path
fi

if [ ! -f "$csv_file" ]; then
    echo "[-] The csv file does not exist: $csv_file"
    exit 1
fi
echo "[+] Experiment type: $experiment_type"
echo "[+] CSV file: $csv_file"

if [ ! -d "$dir_linux_next" ]; then
    echo "[-] The Linux-next directory does not exist: $dir_linux_next"
    exit 1
fi

if [ ! -d "$syzkaller_path" ]; then
    echo "[-] syzkaller directory does not exist: $syzkaller_path"
    exit 1
fi

if [ ! -d "$syzbot_config_files_path" ]; then
    echo "[-] The syzbot config files directory does not exist: $syzbot_config_files_path"
    exit 1
fi

if [ ! -d "$debian_image_path" ]; then
    echo "[-] Debian images directory does not exist: $debian_image_path"
    exit 1
fi

echo "[*] Starting the fuzzing experiments..."
echo "[*] Logs are saved in $log_file"

syzkaller_port=56700

while ss -tuln | grep -q ":$syzkaller_port\b"; do
    ((syzkaller_port++))
done

echo "[*] Syzkaller port: $syzkaller_port"

while IFS=, read -r commit_hash syzbot_config_name git_tag repaired_config_name; do
    echo "[+] Read Config Name: $syzbot_config_name"
    echo "[+] Read Commit Hash: $commit_hash"
    echo "[+] Syzkaller port: $syzkaller_port"
    echo "[+] Unix time: $unix_time"
    # go to linux-next directory
    cd $dir_linux_next

    echo "[+] Switching to linux-next directory: $dir_linux_next"

    echo "[+] Cleaning the linux-next repo"

    git clean -dfx || { echo "[-] Git clean failed"; exit 1; }

    echo "[+] Resetting the git head"
    git reset --hard origin/master || { echo "[-] Git reset failed"; exit 1; }

    echo "[+] Checking out to the tag $git_tag"
    git checkout -f $git_tag || { echo "[-] Git checkout failed for tag $git_tag"; exit 1; }

    # bring syzbot config file to the linux-next directory
    if [ ! -f "${syzbot_config_files_path}/${syzbot_config_name}" ]; then
        echo "[-] The syzbot config file does not exist: ${syzbot_config_files_path}/${syzbot_config_name}"
        exit 1
    fi

    echo "[+] Starting making defconfig..."
    make CC=/usr/local/bin/gcc defconfig

    if [ "$1" == "default" ]; then
        echo "[+] Copying the syzbot config file to .config"
        cp ${syzbot_config_files_path}/${syzbot_config_name} $dir_linux_next/.config
    elif [ "$1" == "repaired" ]; then
        echo "[+] Copying the repaired config file to .config"
        cp ${repaired_config_files_path}/${repaired_config_name} .config
    fi

    echo "[+] Made defconfig. Now making kvm_guest.config..."
    make CC=/usr/local/bin/gcc kvm_guest.config

    echo "[+] Made kvm_guest.config"

    echo "[+] Adding default syzkaller configs to .config file"
    # add syzkaller default config options
    ./scripts/config --enable CONFIG_KCOV --enable CONFIG_DEBUG_INFO --enable CONFIG_DEBUG_INFO_DWARF4 --enable CONFIG_KASAN --enable CONFIG_KASAN_INLINE --enable CONFIG_CONFIGFS_FS --enable CONFIG_SECURITYFS --enable CONFIG_CMDLINE_BOOL --set-val CONFIG_CMDLINE "net.ifnames=0"

    echo "[+] Making olddefconfig..."
    make CC=/usr/local/bin/gcc olddefconfig
    echo "[+] Made olddefconfig"
    echo "[+] Compiling the kernel..."
    make CC=/usr/local/bin/gcc -j"$(nproc)" || { echo "[-] Kernel compilation failed"; exit 1; }
    echo "[+] Compiled the kernel!"

    workdir_name="$output_path/fuzzing_results/syzkaller_workdir_${syzbot_config_name}_${commit_hash}"
    mkdir -p $workdir_name

    echo "[+] Created workdir ${workdir_name} for the current session"
    echo "[+] Creating new config file for syzkaller config"

    # check if syz-manager config file exists,
    # if not, create a new one
    if [ ! -f "$REPO_ROOT/$syzkaller_path/my.cfg" ]; then
        echo "[-] The syzkaller config file does not exist: $syzkaller_path/my.cfg"
        echo "[+] Creating a new syzkaller config file"
        touch "$REPO_ROOT/$syzkaller_path/my.cfg"
    fi

    cat > "$REPO_ROOT/$syzkaller_path/my.cfg" <<EOF
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
        "mem": 4098
      }
    }
EOF

    mkdir -p "$output_path/fuzzing_instance_logs/"
    fuzzing_instance_log_path="$output_path/fuzzing_instance_logs/syzkaller_terminal_${syzbot_config_name}_${commit_hash}.log"

    echo "[+] Writing logs to ${fuzzing_instance_log_path}"
    timeout 12h "$REPO_ROOT/$syzkaller_path/bin/syz-manager" -config=$REPO_ROOT/$syzkaller_path/my.cfg 2>&1 | tee ${fuzzing_instance_log_path};
    exit_status_timeout=${PIPESTATUS[0]}

    if [ $exit_status_timeout -eq 0 ]; then
        echo "[+] Fuzzing instance completed successfully"
    elif [ $exit_status_timeout -eq 124 ]; then
        echo "[+] Fuzzing instance timed out after 12 hours"
    elif [ $exit_status_timeout -ge 128 ]; then
        echo "[-] Fuzzing instance terminated by signal $signal_number"
    else
        echo "[-] Fuzzing instance exited with error code $exit_status_timeout"
    fi

    syzkaller_port=$((syzkaller_port + 1))

    echo "[+] All steps completed!"

done < "$csv_file"
