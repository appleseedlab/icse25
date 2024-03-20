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
    --syzkaller-config)
      syzkaller_config="$2"
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

echo "[+] making defconfig and kvm_guest.config"
make defconfig
make kvm_guest.config

echo "[+] copying syzkaller config file to the kernel directory"
cp $syzkaller_config .config

echo "[+] making olddefconfig"
make olddefconfig

# build the kernel with the repaired configuration file
echo "[+] compiling the kernel"
make -j`nproc`

sleep 5

# create working directory for syzkaller
echo "[+] creating working directory"
mkdir -p $workdir

echo "[+] creating a text file to save syzkaller's output to"
touch $syzkaller_output

echo "[+] creating tmux session and running syzkaller"
# creating tmux session and running syzkaller in it
tmux new-session -d -s syzkaller_10day_experiment "timeout 240h ~/opt/syzkaller/bin/syz-manager -config=/home/anon/opt/syzkaller/my.cfg 2>&1 | tee ${syzkaller_output}; exec $SHELL"