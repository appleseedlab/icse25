if [ "$#" -ne 6 ]; then
        echo "[!] Usage: ./program <csv-file> <path to linux-next> <path to syzkaller> \
        <path to syzbot configs> <path to output folder>"
        echo "[-] Exiting..."
        exit 9
fi

csv_file=$1
dir_linux_next=$2
syzkaller_path=$3
debian_image_path=$4
syzbot_config_files_path=$5
output_path=$6

unix_time=$(printf '%(%s)T\n' -1)
syzkaller_port=56700

while IFS=, read -r commit_hash syzbot_config_name git_tag; do
    echo "[+] Read Config Name: $syzbot_config_name"
    echo "[+] Read Commit Hash: $commit_hash"
    # go to linux-next directory
    cd $dir_linux_next

    echo "[+] Switching to linux-next directory: $dir_linux_next"

    echo "[+] Cleaning the linux-next repo"

    git clean -dfx

    echo "[+] Resetting the git head"
    git reset --hard origin/master

    echo "[+] Checking out to the tag $git_tag"
    git checkout -f $git_tag

    # bring syzbot config file to the linux-next directory
    cp ${syzbot_config_files_path}/${syzbot_config_name} $dir_linux_next

    echo "[+] Starting making defconfig..."
    make defconfig

    echo "[+] Made defconfig. Now making kvm_guest.config..."

    cp ${syzbot_config_name} .config

    make kvm_guest.config

    echo "[+] Made kvm_guest.config"

    echo "[+] Adding default syzkaller configs to .config file"
    # add syzkaller default config options
    echo "CONFIG_KCOV=y" >> .config
    echo "CONFIG_DEBUG_INFO=y" >> .config
    echo "CONFIG_DEBUG_INFO_DWARF4=y" >> .config
    echo "CONFIG_KASAN=y" >> .config
    echo "CONFIG_KASAN_INLINE=y" >> .config
    echo "CONFIG_CONFIGFS_FS=y" >> .config
    echo "CONFIG_SECURITYFS=y" >> .config
    echo "CONFIG_CMDLINE_BOOL=y" >> .config
    #echo "CONFIG_DEBUG_INFO_BTF=n" >> .config
    echo "CONFIG_CMDLINE=\"net.ifnames=0\"" >> .config

    echo "[+] Making olddefconfig..."
    make olddefconfig
    echo "[+] Made olddefconfig"
    echo "[+] Compiling the kernel..."
    make -j`nproc`
    echo "[+] Compiled the kernel!"

    mkdir -p $output_path/fuzzing_results/$unix_time/default_syzkaller_configs/syzkaller_default_${syzbot_config_name}_${commit_hash}

    workdir_name="$output_path/fuzzing_results/$unix_time/default_syzkaller_configs/syzkaller_default_${syzbot_config_name}_${commit_hash}"

    echo "[+] Created workdir ${workdir_name} for the current session"
    echo "[+] Creating new config file for syzkaller config"
    # create new config file for syzkaller config
    echo '{' > "$syzkaller_path/my.cfg"
    echo '  "target": "linux/amd64",' >> "$syzkaller_path/my.cfg"
    echo "  \"http\": \"127.0.0.1:$syzkaller_port\"," >> "$syzkaller_path/my.cfg"

    printf '  "workdir": "%s",\n' "$workdir_name" >> "$syzkaller_path/my.cfg"

    echo "  \"kernel_obj\": \"$dir_linux_next\"," >> "$syzkaller_path/my.cfg"
    echo "  \"image\": \"$debian_image_path/bullseye.img\"," >> "$syzkaller_path/my.cfg"
    echo "  \"sshkey\": \"$debian_image_path/bullseye.id_rsa\"," >> "$syzkaller_path/my.cfg"
    echo "  \"syzkaller\": \"$syzkaller_path\"," >> "$syzkaller_path/my.cfg"
    echo '  "procs": 8,' >> "$syzkaller_path/my.cfg"
    echo '  "type": "qemu",' >> "$syzkaller_path/my.cfg"
    echo '  "vm": {' >> "$syzkaller_path/my.cfg"
    echo '          "count": 8,' >> "$syzkaller_path/my.cfg"
    echo "          \"kernel\": \"$dir_linux_next/arch/x86/boot/bzImage\"," >> "$syzkaller_path/my.cfg"
    echo '          "cpu": 8,' >> "$syzkaller_path/my.cfg"
    echo '          "mem": 4098' >> "$syzkaller_path/my.cfg"
    echo '  }' >> "$syzkaller_path/my.cfg"
    echo '}' >> "$syzkaller_path/my.cfg"

    mkdir -p $output_path/fuzzing_instance_logs/$unix_time/default_syzkaller_configs/
    fuzzing_instance_log_path="$output_path/fuzzing_instance_logs/$unix_time/default_syzkaller_configs/syzkaller_default_${syzbot_config_name}_${commit_hash}"

    echo "[+] Writing logs to ${fuzzing_instance_log_path}"
    timeout 12h $syzkaller_path/bin/syz-manager -config=$syzkaller_path/my.cfg 2>&1 | tee ${fuzzing_instance_log_path};
    sleep 43320

    ((syzkaller_port++))

    echo "[+] All steps completed!"

done < "$csv_file"
