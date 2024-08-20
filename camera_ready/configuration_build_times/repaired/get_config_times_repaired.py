import csv
import argparse
import subprocess
import os
from loguru import logger

def read_from_csv(file_path):
    with open(file_path, 'r') as f:
        reader = csv.reader(f)
        # read data
        data = [row for row in reader]

    return data

def write_results_to_csv(data):
    with open('results.csv', 'w') as f:
        writer = csv.writer(f)
        writer.writerows(data)

def read_args():
    parser = argparse.ArgumentParser(description='Measure time taken for repaired configurations')
    parser.add_argument('-fp', '--file_path', type=str, help='Path to the file containing the repaired configurations')
    parser.add_argument('-ksrc', '--kernel-src', type=str, help='Path to the kernel source code')
    args = parser.parse_args()
    return args

def extract_real_time(output):
    lines = output.split('\n')
    for line in lines:
        if 'real' in line:
            time = line.split()[1]
            return time

    return None

def execute_krepair(kernel_src, repaired_commit_id, config_name, kernel_commit_id):
    total_time = 0

    # perform git checkout
    try:
        subprocess.run(['git', 'checkout', kernel_commit_id], cwd=kernel_src, check=True)
    except subprocess.CalledProcessError as e:
        logger.error(f'Error in git checkout: {e}')
        exit(1)

    # create patch diff
    try:
        result = subprocess.run(['git', 'show', '--output', 'patch.diff'], cwd=kernel_src, check=True, text=True, capture_output=True)
        logger.info(f'Patch diff created: {result.stdout}')
        logger.info(result.stderr)
    except subprocess.CalledProcessError as e:
        logger.error(f'Error in creating patch diff: {e}')
        exit(1)

    # run klocalizer
    klocalizer_command = f"time -p klocalizer -v -a x86_64 --repair {config_name} --include-mutex 'patch_diff' --formulas ../formulacache --define CONFIG_KCOV --define CONFIG_DEBUG_INFO_DWARF4 --define CONFIG_KASAN --define CONFIG_KASAN_INLINE --define CONFIG_CONFIGFS_FS --define CONFIG_SECURITYFS --define CONFIG_CMDLINE_BOOL; rm -rf koverage_files/"
    try:
        result = subprocess.run(klocalizer_command, cwd=kernel_src, check=True, shell=True, text=True, capture_output=True)
        realtime = extract_real_time(result.stderr)
        total_time += float(realtime)
        logger.info(realtime)
    except subprocess.CalledProcessError as e:
        logger.error(f'Error in running klocalizer: {e}')
        exit(1)

    # perform make olddefconfig
    make_olddefconfig_command = "time -p make olddefconfig"
    try:
        result = subprocess.run(make_olddefconfig_command, cwd=kernel_src, check=True, shell=True, text=True, capture_output=True)
        realtime = extract_real_time(result.stderr)
        total_time += float(realtime)
        logger.info(realtime)
    except subprocess.CalledProcessError as e:
        logger.error(f'Error in running make olddefconfig: {e}')
        exit(1)

    return [repaired_commit_id, config_name, kernel_commit_id, total_time]

def process_data(data, kernel_src):
    results = []
    for row in data:
        repaired_commit_id, config_name, kernel_commit_id = row
        config_path  = os.path.join('/home/sanan/research/syzbot_configuration_files', config_name)
        results_row = execute_krepair(kernel_src, repaired_commit_id, config_path, kernel_commit_id)
        results.append(results_row)

    write_results_to_csv(results)

def main():
    args = read_args()
    file_path = args.file_path
    kernel_src = args.kernel_src
    data = read_from_csv(file_path)
    process_data(data, kernel_src)
    # print(data)

if __name__ == '__main__':
    main()
