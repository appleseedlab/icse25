#!/bin/bash

# csv format:
# config_filename,commit_id,tag

# The location of the CSV file
CSV_FILE="/home/anon/research/source_lines.csv"

# The directory where the kernel configuration files are located
CONFIG_FILES_DIR=/home/anon/research/syzbot_configuration_files

# Path to the Linux repository where the operations will be performed
LINUX_REPO_DIR=/home/anon/linux-next

# Change directory to the Linux repository
cd "$LINUX_REPO_DIR" || exit

echo "[+] Inside the linux next directory: $LINUX_REPO_DIR"
sleep 2

# Read the CSV file line by line
while IFS=, read -r config_filename commit_id tag; do
  # Clean the repository
  echo "[+] Cleaning the directory"
  git clean -dfx

  echo "[+] current directory:"
  pwd
  sleep 10

  echo "[+] making defconfig and kvm_guest.config"
  # Make default configurations
  make defconfig && make kvm_guest.config

  # Copy the kernel configuration file from the syzbot_configuration_files directory
  cp "${CONFIG_FILES_DIR}/${config_filename}" .config
  
  sed -i 's/^CONFIG_WERROR=.*/CONFIG_WERROR=n/' $config_filename

  make olddefconfig

  echo "[+] Building the kernel"
  KCFLAGS="-save-temps=obj" make -j`nproc`
  
  sleep 2
  echo "[+] Rsyncing .i to the ~/linux-next-$config_filename-$tag directory"
  rsync -avm --include='*/' --include='*.i' --exclude='*' --prune-empty-dirs --relative "$LINUX_REPO_DIR" /home/anon/linux-next-$config_filename-$tag-default
  
  echo "[+] getting source lines"
  /home/anon/research/source_lines.sh
  
  sleep 2
  echo "[+] Rsyncing source lines to the ~/linux-next-$config_filename-$tag directory"
  rsync -avm --include='*/' --include='*_source_lines.txt' --exclude='*' --prune-empty-dirs --relative "$LINUX_REPO_DIR" /home/anon/linux-next-$config_filename-$tag-default

done < "$CSV_FILE"
# End of the script