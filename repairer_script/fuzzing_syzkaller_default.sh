if [ "$#" -ne 3 ]; then
        echo "[!] Usage: ./program <commit-hash> <syzbot-config-name> <date>"
        echo "[-] Exiting..."
        exit 9
fi

commit_hash=$1

echo "[+] Read Commit Hash: $commit_hash"

syzbot_config_name=$2

git_tag="next-"$3

echo "[+] Read Config Name: $syzbot_config_name"

# go to linux-next directory
dir_linux_next=/home/anon/linux-next
cd $dir_linux_next

echo "[+] Switching to linux-next directory: $dir_linux_next"

echo "[+] Cleaning the linux-next repo"

git clean -dfx

echo "[+] Resetting the git head"
git reset --hard origin/master

echo "[+] Checking out to the tag $git_tag"
git checkout -f $git_tag

# bring syzbot config file to the linux-next directory
cp /home/anon/research/syzbot_configuration_files/${syzbot_config_name} /home/anon/linux-next

echo "[+] Starting making defconfig..."
make defconfig

echo "[+] Made defconfig. Now making kvm_guest.config..."
#cp .config /home/anon/research/raw_coverage_default_configuration_files

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

mkdir /home/anon/opt/syzkaller/syzkaller_default_${syzbot_config_name}_${commit_hash}_$(date +'%m%d%Y')

workdir_name="/home/anon/opt/syzkaller/syzkaller_default_${syzbot_config_name}_${commit_hash}_$(date +'%m%d%Y')"

echo "[+] Creating new config file for syzkaller config"
# create new config file for syzkaller config
echo '{' > /home/anon/opt/syzkaller/my.cfg
echo '  "target": "linux/amd64",' >> /home/anon/opt/syzkaller/my.cfg
echo '  "http": "127.0.0.1:56741",' >> /home/anon/opt/syzkaller/my.cfg

printf '        "workdir": "%s",\n' "$workdir_name" >> /home/anon/opt/syzkaller/my.cfg

echo '  "kernel_obj": "/home/anon/linux-next",' >> /home/anon/opt/syzkaller/my.cfg
echo '  "image": "/home/anon/Documents/opt/my-image/stretch.img",' >> /home/anon/opt/syzkaller/my.cfg
echo '  "sshkey": "/home/anon/Documents/opt/my-image/stretch.id_rsa",' >> /home/anon/opt/syzkaller/my.cfg
echo '  "syzkaller": "/home/anon/opt/syzkaller",' >> /home/anon/opt/syzkaller/my.cfg
echo '  "procs": 8,' >> /home/anon/opt/syzkaller/my.cfg
echo '  "type": "qemu",' >> /home/anon/opt/syzkaller/my.cfg
echo '  "vm": {' >> /home/anon/opt/syzkaller/my.cfg
echo '          "count": 8,' >> /home/anon/opt/syzkaller/my.cfg
echo '          "kernel": "/home/anon/linux-next/arch/x86/boot/bzImage",' >> /home/anon/opt/syzkaller/my.cfg
echo '          "cpu": 8,' >> /home/anon/opt/syzkaller/my.cfg
echo '          "mem": 4098' >> /home/anon/opt/syzkaller/my.cfg
echo '  }' >> /home/anon/opt/syzkaller/my.cfg
echo '}' >> /home/anon/opt/syzkaller/my.cfg

current_date=$(date +'%m%d%Y')
raw_syz_term_out="/home/anon/research/syzkaller_default_terminal_output/raw_${syzbot_config_name}_${commit_hash}_${current_date}"

echo "[+] Creating new tmux sesion"
tmux new-session -d -s raw_${commit_hash} "timeout 12h ~/opt/syzkaller/bin/syz-manager -config=/home/anon/opt/syzkaller/my.cfg 2>&1 | tee ${raw_syz_term_out}; exec $SHELL"

echo "[+] All steps completed!"
