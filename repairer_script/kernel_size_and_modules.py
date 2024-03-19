import csv
import os
import subprocess
import argparse
import re

def get_kernel_version(kernel_dir):
    """Get the kernel version from the kernel directory."""
    try:
        output = subprocess.check_output(f'make -C {kernel_dir} kernelversion', shell=True)
        decoded_output = output.decode('utf-8')

        # Use regular expression to extract the version number
        match = re.search(r'\d+\.\d+\.\d+', decoded_output)
        if match:
            return match.group()
        else:
            print("No kernel version found in the output.")
            return None
    except subprocess.CalledProcessError as e:
        print(f"Error obtaining kernel version: {e}")
        return None

def get_modules_path(kernel_dir):
    """Get the path to the compiled kernel modules."""
    kernel_version = get_kernel_version(kernel_dir)
    if kernel_version:
        modules_path = os.path.join(kernel_dir, f'lib/modules/{kernel_version}/kernel')
        print(f"Modules path: {modules_path}")
        return modules_path
    else:
        return None

def get_size_mb(file_path):
    """Get the size of a file or total size of files in a directory in megabytes."""
    if not os.path.exists(file_path):
        return 0

    if os.path.isfile(file_path):
        return os.path.getsize(file_path) / (1024 * 1024)

    total_size = 0
    if os.path.isdir(file_path):
        for root, dirs, files in os.walk(file_path):
            for file in files:
                total_size += os.path.getsize(os.path.join(root, file))

    return total_size / (1024 * 1024)

def modify_kernel_config(kernel_dir, config_key, config_value):
    """Modify a specific configuration in the kernel .config file."""
    config_path = os.path.join(kernel_dir, ".config")
    with open(config_path, 'r') as file:
        lines = file.readlines()
    
    with open(config_path, 'w') as file:
        for line in lines:
            if line.startswith(f'{config_key}='):
                file.write(f'{config_key}={config_value}\n')
            else:
                file.write(line)

def compile_kernel(kernel_dir):
    """Run kernel compilation commands."""
    print(f"Compiling the kernel...")
    try:
        subprocess.run(f'make -C {kernel_dir} -j`nproc`', shell=True, check=True)
    except subprocess.CalledProcessError:
        print("Compilation error: Try to disable CONFIG_DEBUG_INFO_BTF.")
        # Modify the kernel configuration
        modify_kernel_config(kernel_dir, "CONFIG_DEBUG_INFO_BTF", "n")
        print("Recompiling the kernel with CONFIG_DEBUG_INFO_BTF disabled.")
        subprocess.run(f'make -C {kernel_dir} -j`nproc`', shell=True, check=True)

def process_row(kernel_dir, commit_id, config_file_syzbot, config_file_repaired, csv_file_path):
    # Checkout to the commit ID
    print(f"Processing commit id: {commit_id}, config_file_syzbot: {config_file_syzbot}, config_file_repaired: {config_file_repaired}")
    print(f"Cleaning kernel dir: {kernel_dir}")
    subprocess.run(f'git -C {kernel_dir} clean -dfx', shell=True, check=True)
    print(f"Checking out to the commit: {commit_id}")
    subprocess.run(f'git -C {kernel_dir} checkout {commit_id}', shell=True, check=True)
    subprocess.run(f'make -C {kernel_dir} defconfig', shell=True, check=True)
    subprocess.run(f'make -C {kernel_dir} kvm_guest.config', shell=True, check=True)

    # Process for syzbot configuration
    config_file_path = os.path.join('~/research/syzbot_configuration_files', config_file_syzbot)
    subprocess.run(f'cp {config_file_path} {os.path.join(kernel_dir, ".config")}', shell=True, check=True)
    print(f"Making olddefconfig")
    subprocess.run(f'make -C {kernel_dir} olddefconfig', shell=True, check=True)
    compile_kernel(kernel_dir)
    bzImage_size = get_size_mb(os.path.join(kernel_dir, 'arch/x86/boot/bzImage'))
    modules_path = get_modules_path(kernel_dir)
    if modules_path and os.path.exists(modules_path):
        modules_size = get_size_mb(modules_path)
    else:
        print(f"Modules path not found: {modules_path}")
        modules_size = 0
    total_size = bzImage_size + modules_size

    # Write results for syzbot configuration
    with open(csv_file_path, 'a', newline='') as write_file:
        csv_writer = csv.writer(write_file)
        csv_writer.writerow([commit_id, config_file_syzbot, config_file_repaired, bzImage_size, modules_size, total_size])

    # Process for repaired configuration
    config_file_path = os.path.join('~/research/repaired_configuration_files', config_file_repaired)
    subprocess.run(f'cp {config_file_path} {os.path.join(kernel_dir, ".config")}', shell=True, check=True)
    subprocess.run(f'make -C {kernel_dir} olddefconfig', shell=True, check=True)
    compile_kernel(kernel_dir)
    bzImage_size = get_size_mb(os.path.join(kernel_dir, 'arch/x86/boot/bzImage'))
    modules_path = get_modules_path(kernel_dir)
    if modules_path and os.path.exists(modules_path):
        modules_size = get_size_mb(modules_path)
    else:
        print(f"Modules path not found: {modules_path}")
        modules_size = 0
    total_size = bzImage_size + modules_size

    # Write results for repaired configuration
    with open(csv_file_path, 'a', newline='') as write_file:
        csv_writer = csv.writer(write_file)
        csv_writer.writerow([commit_id, config_file_syzbot, config_file_repaired, bzImage_size, modules_size, total_size])


def main():
    parser = argparse.ArgumentParser(description='Kernel Compilation Script')
    parser.add_argument('--kernel-dir', required=True, help='Path to the kernel source directory')
    parser.add_argument('--csv-file', required=True, help='Path to the CSV file')
    args = parser.parse_args()

    with open(args.csv_file, 'r') as file:
        csv_reader = csv.reader(file)
        next(csv_reader, None)  # Skip header row if present

        for row in csv_reader:
            process_row(args.kernel_dir, *row, args.csv_file)

if __name__ == "__main__":
    main()
