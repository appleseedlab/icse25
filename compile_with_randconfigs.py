import argparse
import subprocess
import logging
import time
import shutil
import git
import os
import csv
import json


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate random configurations for the kernel"
    )
    parser.add_argument(
        "-k",
        "--kernel_src",
        type=str,
        required=True,
        help="Path to the kernel source directory",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        type=str,
        required=False,
        help="Logging level",
    )
    parser.add_argument(
        "-sc",
        "--syzkaller_config",
        type=str,
        required=True,
        help="Path to syzkaller syz-manager configuration file",
    )
    parser.add_argument(
        "-ocl",
        "--output_config_list",
        type=str,
        required=True,
        help="Path to save output syzkaller syz-manager configuration file list",
    )
    parser.add_argument(
        "-o",
        "--output_dir",
        type=str,
        required=True,
        help="Output directory",
    )

    args = parser.parse_args()
    return args


def git_clean(kernel_src):
    repo = git.Repo(kernel_src)

    untracked_files = repo.untracked_files

    for file in untracked_files:
        file_path = os.path.join(kernel_src, file)
        if os.path.isfile(file_path):
            os.remove(file_path)
        elif os.path.isdir(file_path):
            shutil.rmtree(file_path)


def save_to_csv(output_dir, seed, probability, config_path):
    with open(
        f"{output_dir}/randconfig_experiment_results.csv", "w", newline=""
    ) as csv_file:
        csvwriter = csv.writer(csv_file)
        csvwriter.writerow([seed, probability, config_path])


def generate_randconfigs(kernel_src, output_dir):
    config_path = f"{kernel_src}/.config"
    generated_config_files = []

    for prob in range(10, 100, 10):
        git_clean(kernel_src)

        seed = int(time.time())
        command = f"KCONFIG_SEED={seed} KCONFIG_PROBABILTIY={prob} make randconfig"
        logging.debug(f"Seed: {seed}, Probability: {prob}")

        output_config_path = f"{output_dir}/{seed}_{prob}.config"
        try:
            result = subprocess.run(
                command, shell=True, cwd=kernel_src, check=True, capture_output=True
            )
            logging.debug(result.stdout)

        except Exception as e:
            logging.error(e)

        logging.debug(f"Copying config file from {config_path} to {output_config_path}")
        shutil.copy(config_path, output_config_path)
        generated_config_files.append(output_config_path)
        save_to_csv(output_dir, seed, prob, output_config_path)

    return generated_config_files


def compile_kernel(kernel_src_list, generated_config_files, output_dir):
    config_not_compiled = []
    for kernel_src, config_file in zip(kernel_src_list, generated_config_files):
        git_clean(kernel_src)
        logging.debug(f"Working on config file: {config_file}")
        command = f"KCONFIG_CONFIG={config_file} make -C {kernel_src} -j$(nproc)"
        try:
            result = subprocess.run(
                command,
                shell=True,
                cwd=kernel_src,
                check=True,
                capture_output=True,
                text=True,
            )
            logging.debug(result.stdout)

            if result.returncode != 0:
                logging.error(result.stderr)
            # else:
            #     bzimage_path = f"{kernel_src}/arch/x86/boot/bzImage"
            #     try:
            #         shutil.copy(bzimage_path, output_dir)
            #     except shutil.Error as e:
            #         logging.error(e)

        except subprocess.CalledProcessError as e:
            logging.error(e)
            config_not_compiled.append(config_file)

    return config_not_compiled



def main():
    args = parse_args()
    loglevel = args.verbose
    numeric_level = getattr(logging, loglevel.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError("Invalid log level: %s" % loglevel)

    logging.basicConfig(level=loglevel)
    generate_randconfigs(args.kernel_src, args.output_dir)


if __name__ == "__main__":
    main()
