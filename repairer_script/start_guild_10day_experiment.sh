#!/bin/bash

# get input from cmd line
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --kernel-path)
      kernel_dir="$2"
      shift # past argument
      shift # past value
      ;;
    --config-file-to-repair)
      config_file="$2"
      shift # past argument
      shift # past value
      ;;
    --diff)
      diff_file="$2"
      shift # past argument
      shift # past value
      ;;
    --workdir)
      workdir="$2"
      shift # past argument
      shift # past value
      ;;
    --syzkaller-output)
      syzkaller_output="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      echo "[!] Unknown option"
      echo "[!] Usage: $0 --kernel-path path/to/kernel --config-file-to-repair path/to/config --diff path/to/diff --workdir path/to/workdir --syzkaller-output path/to/output"
      exit 1
      ;;
  esac
done

# moving to the kernel directory
echo "[+] moving to the kernel directory"
cd $kernel_dir

# clean the kernel directory
echo "[+] cleaning the kernel directory:"
pwd
git clean -dfx

echo "[+] copyinh syzkaller config and diff file to the kernel directory"
cp $config_file .
cp $diff_file .

# source kmax environment
echo "[+] Sourcing kmax environment"
source ~/env_kmax/bin/activate

echo "[+] Running klocalizer to repair $config_file"

# run klocalizer to get repaired config file
klocalizer --repair $config_file -a x86_64 --define CONFIG_KCOV --define CONFIG_KASAN --define CONFIG_KASAN_INLINE --define CONFIG_DEBUG_INFO_DWARF4 --define CONFIG_CONFIGFS_FS --define CONFIG_SECURITYFS --define CONFIG_CMDLINE_BOOL --define CONFIG_PAHOLE_HAS_SPLIT_BTF --define CONFIG_CLOSURES --define CONFIG_PAHOLE_HAS_LANG_EXCLUDE --define CONFIG_BCACHEFS_QUOTA --define CONFIG_BCACHEFS_DEBUG --define CONFIG_BCACHEFS_FS --define CONFIG_BATMAN_ADV_BATMAN_V --define CONFIG_BATMAN_ADV_NC --define CONFIG_BATMAN_ADV_MCAST --define CONFIG_PROVE_RCU --include-mutex $diff_file

# make the new configuration file
KCONFIG_CONFIG=./1-x86_64.config make.cross ARCH=x86_64 olddefconfig clean kernel/trace/trace_kprobe.o

# build the kernel with the repaired configuration file
echo "[+] compiling the kernel"
KCONFIG_CONFIG=1-x86_64.config make -j`nproc`

sleep 2

# create working directory for syzkaller
echo "[+] creating working directory"
mkdir -p $workdir

echo "[+] creating a text file to save syzkaller's output to"
touch $syzkaller_output

echo "[+] creating tmux session and running syzkaller"
# creating tmux session and running syzkaller in it
tmux new-session -d -s 10day_experiment "timeout 240h ~/opt/syzkaller/bin/syz-manager -config=/home/sanan/opt/syzkaller/my.cfg 2>&1 | tee ${syzkaller_output}; exec $SHELL"