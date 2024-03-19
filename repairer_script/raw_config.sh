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
dir_linux_next=/home/sanan/linux-next
cd $dir_linux_next

echo "[+] Switching to linux-next directory: $dir_linux_next"

echo "[+] Cleaning the linux-next repo"

git clean -dfx

echo "[+] Resetting the git head"
git reset --hard origin/master

echo "[+] Checking out to the tag $git_tag"
git checkout -f $git_tag

# bring syzbot config file to the linux-next directory
cp /home/sanan/research/syzbot_configuration_files/${syzbot_config_name} /home/sanan/linux-next

echo "[+] Starting making defconfig..."
make defconfig

echo "[+] Made defconfig. Now making kvm_guest.config..."

make kvm_guest.config

echo "[+] Made kvm_guest.config"

cp .config /home/sanan/research/raw_coverage_default_configuration_files

cp ${syzbot_config_name} .config

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

mkdir /home/sanan/opt/syzkaller/raw_coverage_${syzbot_config_name}_${commit_hash}_$(date +'%m%d%Y')

workdir_name="/home/sanan/opt/syzkaller/raw_coverage_${syzbot_config_name}_${commit_hash}_$(date +'%m%d%Y')"

echo "[+] Creating new config file for syzkaller config"
# create new config file for syzkaller config
echo '{' > /home/sanan/opt/syzkaller/my.cfg
echo '  "target": "linux/amd64",' >> /home/sanan/opt/syzkaller/my.cfg
echo '  "http": "127.0.0.1:56741",' >> /home/sanan/opt/syzkaller/my.cfg

printf '        "workdir": "%s",\n' "$workdir_name" >> /home/sanan/opt/syzkaller/my.cfg

echo '  "kernel_obj": "/home/sanan/linux-next",' >> /home/sanan/opt/syzkaller/my.cfg
echo '  "image": "/home/sanan/Documents/opt/my-image/stretch.img",' >> /home/sanan/opt/syzkaller/my.cfg
echo '  "sshkey": "/home/sanan/Documents/opt/my-image/stretch.id_rsa",' >> /home/sanan/opt/syzkaller/my.cfg
echo '  "syzkaller": "/home/sanan/opt/syzkaller",' >> /home/sanan/opt/syzkaller/my.cfg
echo '  "procs": 8,' >> /home/sanan/opt/syzkaller/my.cfg
echo '  "type": "qemu",' >> /home/sanan/opt/syzkaller/my.cfg
echo '  "vm": {' >> /home/sanan/opt/syzkaller/my.cfg
echo '          "count": 8,' >> /home/sanan/opt/syzkaller/my.cfg
echo '          "kernel": "/home/sanan/linux-next/arch/x86/boot/bzImage",' >> /home/sanan/opt/syzkaller/my.cfg
echo '          "cpu": 8,' >> /home/sanan/opt/syzkaller/my.cfg
echo '          "mem": 4098' >> /home/sanan/opt/syzkaller/my.cfg
echo '  }' >> /home/sanan/opt/syzkaller/my.cfg
echo '}' >> /home/sanan/opt/syzkaller/my.cfg

current_date=$(date +'%m%d%Y')
raw_syz_term_out="/home/sanan/research/raw_coverage_syzkaller_terminal_output/raw_${syzbot_config_name}_${commit_hash}_${current_date}"

echo "[+] Creating new tmux sesion"
tmux new-session -d -s raw_${commit_hash} "timeout 12h ~/opt/syzkaller/bin/syz-manager -config=/home/sanan/opt/syzkaller/my.cfg 2>&1 | tee ${raw_syz_term_out}; exec $SHELL"

echo "[+] All steps completed!"
