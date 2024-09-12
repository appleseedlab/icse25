if [ "$#" -ne 7 ]; then
        echo "[!] Usage: ./program <patch-commit-id> <default-config-file-used> \
        <fuzzed-linux-commit-id> <path to linux-next> <path to syzkaller> \
        <path to syzbot configs> <path to output folder>"
        echo "[-] Exiting..."
        exit 9
fi

commit_hash=$1

echo "[+] Read Commit Hash: $commit_hash"

syzbot_config_name=$2
git_tag=$3
dir_linux_next=$4
syzkaller_path=$5
syzbot_config_files_path=$6
output_path=$7

unix_time=$(printf '%(%s)T\n' -1)

echo "[+] Read Config Name: $syzbot_config_name"

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

mkdir -p $output_path/fuzzing_results_$unix_time/default_syzkaller_configs/syzkaller_default_${syzbot_config_name}_${commit_hash}

workdir_name="$output_path/fuzzing_results_$unix_time/default_syzkaller_configs/syzkaller_default_${syzbot_config_name}_${commit_hash}"

echo "[+] Creating new config file for syzkaller config"
# create new config file for syzkaller config
echo '{' > $syzkaller_path/my.cfg
echo '  "target": "linux/amd64",' >> $syzkaller_path/my.cfg
echo '  "http": "127.0.0.1:56741",' >> $syzkaller_path/my.cfg

printf '        "workdir": "%s",\n' "$workdir_name" >> $syzkaller_path/my.cfg

echo '  "kernel_obj": "/home/anon/linux-next",' >> $syzkaller_path/my.cfg
echo '  "image": "/home/anon/Documents/opt/my-image/stretch.img",' >> $syzkaller_path/my.cfg
echo '  "sshkey": "/home/anon/Documents/opt/my-image/stretch.id_rsa",' >> $syzkaller_path/my.cfg
echo '  "syzkaller": "$syzkaller_path",' >> $syzkaller_path/my.cfg
echo '  "procs": 8,' >> $syzkaller_path/my.cfg
echo '  "type": "qemu",' >> $syzkaller_path/my.cfg
echo '  "vm": {' >> $syzkaller_path/my.cfg
echo '          "count": 8,' >> $syzkaller_path/my.cfg
echo '          "kernel": "/home/anon/linux-next/arch/x86/boot/bzImage",' >> $syzkaller_path/my.cfg
echo '          "cpu": 8,' >> $syzkaller_path/my.cfg
echo '          "mem": 4098' >> $syzkaller_path/my.cfg
echo '  }' >> $syzkaller_path/my.cfg
echo '}' >> $syzkaller_path/my.cfg

mkdir -p $output_path/fuzzing_instance_logs/
fuzzing_instance_log_path="$output_path/fuzzing_instance_logs/default_syzkaller_configs/syzkaller_default_${syzbot_config_name}_${commit_hash}"

timeout 12h $syzkaller_path/bin/syz-manager -config=$syzkaller_path/my.cfg 2>&1 | tee ${fuzzing_instance_log_path};

echo "[+] All steps completed!"
