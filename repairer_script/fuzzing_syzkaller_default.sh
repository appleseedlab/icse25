set -euo pipefail

if [ "$#" -ne 6 ]; then
    echo "[!] Usage: ./program <csv-file> <path to linux-next> <path to syzkaller> <path to debian image> <path to syzbot configs> <path to output folder>"
    echo "[-] Exiting..."
    exit 9
fi

csv_file=$1
dir_linux_next=$2
syzkaller_path=$3
debian_image_path=$4
syzbot_config_files_path=$5
output_path=$6

if [ ! -d "$dir_linux_next" ]; then
    echo "[-] The Linux-next directory does not exist: $dir_linux_next"
    exit 1
fi

if [ ! -d "$syzkaller_path" ]; then
    echo "[-] syzkaller directory does not exist: $syzkaller_path"
    exit 1
fi

if [ ! -d "$debian_image_path" ]; then
    echo "[-] Debian images directory does not exist: $debian_image_path"
    exit 1
fi

unix_time=$(printf '%(%s)T\n' -1)
output_path=$output_path/$unix_time
log_file=$output_path/$unix_time/main_script_logs.log

exec > >(tee -i "$log_file") 2>&1

syzkaller_port=56700

while ss -tuln | grep -q ":$syzkaller_port\b"; do
    ((syzkaller_port++))
done

while IFS=, read -r commit_hash syzbot_config_name git_tag; do
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
    cp ${syzbot_config_files_path}/${syzbot_config_name} $dir_linux_next

    echo "[+] Starting making defconfig..."
    make defconfig

    echo "[+] Made defconfig. Now making kvm_guest.config..."

    cp ${syzbot_config_name} .config

    make kvm_guest.config

    echo "[+] Made kvm_guest.config"

    echo "[+] Adding default syzkaller configs to .config file"
    # add syzkaller default config options
    cat >> .config <<EOF
    CONFIG_KCOV=y
    CONFIG_DEBUG_INFO=y
    CONFIG_DEBUG_INFO_DWARF4=y
    CONFIG_KASAN=y
    CONFIG_KASAN_INLINE=y
    CONFIG_CONFIGFS_FS=y
    CONFIG_SECURITYFS=y
    CONFIG_CMDLINE_BOOL=y
    CONFIG_CMDLINE="net.ifnames=0"
EOF

    echo "[+] Making olddefconfig..."
    make olddefconfig
    echo "[+] Made olddefconfig"
    echo "[+] Compiling the kernel..."
    make -j"$(nproc)" || { echo "[-] Kernel compilation failed"; exit 1; }
    echo "[+] Compiled the kernel!"

    workdir_name="$output_path/fuzzing_results/syzkaller_workdir_${syzbot_config_name}_${commit_hash}"
    mkdir -p $workdir_name

    echo "[+] Created workdir ${workdir_name} for the current session"
    echo "[+] Creating new config file for syzkaller config"

    cat > "$syzkaller_path/my.cfg" <<EOF
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
        "mem": 4098
      }
    }
EOF

    fuzzing_instance_log_path="$output_path/fuzzing_instance_logs/syzkaller_terminal_${syzbot_config_name}_${commit_hash}.log"

    echo "[+] Writing logs to ${fuzzing_instance_log_path}"
    timeout 12h $syzkaller_path/bin/syz-manager -config=$syzkaller_path/my.cfg 2>&1 | tee ${fuzzing_instance_log_path};
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
