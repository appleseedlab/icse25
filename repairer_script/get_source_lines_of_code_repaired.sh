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

  echo "[+] making defconfig and kvm_guest.config"
  # Make default configurations
  make defconfig && make kvm_guest.config

  # Copy the kernel configuration file from the syzbot_configuration_files directory
  cp "${CONFIG_FILES_DIR}/${config_filename}" .

  # Show the commit and redirect output to a file with commit id as name
  git show "$commit_id" > "${commit_id}.diff"
  
  echo "[+] generated diff file: $commit_id.diff"
  sleep 2

  echo "[+] Running klocalizer"
  # Run klocalizer with the given options
  klocalizer -v -a x86_64 --repair "${config_filename}" --include-mutex "${commit_id}.diff" --formulas ../formulacache --define CONFIG_KCOV --define CONFIG_DEBUG_INFO_DWARF4 --define CONFIG_KASAN --define CONFIG_KASAN_INLINE --define CONFIG_CONFIGFS_FS --define CONFIG_SECURITYFS --define CONFIG_CMDLINE_BOOL --undefine CONFIG_WERROR

  sleep 2
  # Remove the koverage_files directory
  rm -rf koverage_files/

  mv 0-x86_64.config .config

  make olddefconfig

  echo "[+] Building the kernel"
  KCFLAGS="-save-temps=obj" make -j14
  
  sleep 2
  echo "[+] Rsyncing .i to the ~/linux-next-$config_filename-$tag directory"
  rsync -avm --include='*/' --include='*.i' --exclude='*' --prune-empty-dirs --relative "$LINUX_REPO_DIR" /home/anon/linux-next-$config_filename-$tag-repaired
  
  echo "[+] getting source lines"
  /home/anon/research/source_lines.sh
  
  sleep 2
  echo "[+] Rsyncing source lines to the ~/linux-next-$config_filename-$tag directory"
  rsync -avm --include='*/' --include='*_source_lines.txt' --exclude='*' --prune-empty-dirs --relative "$LINUX_REPO_DIR" /home/anon/linux-next-$config_filename-$tag-repaired


done < "$CSV_FILE"

# End of the script
