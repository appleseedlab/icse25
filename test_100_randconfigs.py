import argparse
import subprocess
import logging
import time
import shutil
import git
import os
import csv
import json
import sys
import requests
import signal


def parse_args():
    """
    This function parses the command line arguments and returns them
    Returns: parsed arguments
    """
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
        "-o",
        "--output_dir",
        type=str,
        required=True,
        help="Output directory",
    )
    parser.add_argument(
        "-gr",
        "--gitref",
        type=str,
        default="v6.7",
        required=False,
        help="Git reference to checkout to",
    )
    args = parser.parse_args()
    return args


def git_clean(kernel_src):
    """
    This function performs git clean on the provided kernel source
    Args:
    kernel_src: Path to the linux kernel source
    """
    # repo = git.Repo(kernel_src)
    #
    # untracked_files = repo.untracked_files
    #
    # for file in untracked_files:
    #     file_path = os.path.join(kernel_src, file)
    #     if os.path.isfile(file_path):
    #         os.remove(file_path)
    #     elif os.path.isdir(file_path):
    #         shutil.rmtree(file_path)
    command = "git clean -dfx"
    try:
        result = subprocess.run(
            command, shell=True, cwd=kernel_src, check=True, capture_output=True
        )
        logging.debug(result.stdout)

    except Exception as e:
        logging.error(e)


def save_to_csv(csv_file_path, seed, probability, config_path, csvname_seed) -> str:
    """
    This function saves the seed, probability and config path to a csv file
    Args:
    output_dir: output directory
    seed: seed used to generate the configuration
    probability: probability used to generate the configuration
    config_path: path to the generated configuration file
    Returns: path to the csv file
    """
    columns = ["Seed", "Probability", "Config Path", "Compiled", "Booted"]

    # Check if file is empty or does not exist to decide on writing the headers
    file_exists = os.path.exists(csv_file_path)
    is_empty = not os.path.getsize(csv_file_path) if file_exists else True

    with open(
        csv_file_path,
        "a",
        newline="",
    ) as csv_file:
        csvwriter = csv.writer(csv_file)

        if is_empty:
            csvwriter.writerow(columns)

        csvwriter.writerow([seed, probability, config_path, "", ""])

    return csv_file_path


def generate_randconfigs(kernel_src, output_dir) -> tuple[list, str]:
    """
    This function generates random configurations for the kernel
    It uses the randconfig make target to generate random configurations with seeds of current time and probability from 10 to 90
    Then it copies the generated configuration files to the output directory
    Later, it saves the seed, probability and config path to a csv file
    Args:
    kernel_src: path to the kernel source
    output_dir: output directory
    Returns: list of generated configuration files
    Raises: Exception
    """
    config_path = f"{kernel_src}/.config"
    generated_config_files = []
    csvname_seed = int(time.time())

    csv_file_path = f"{output_dir}/randconfig_experiment_results_{csvname_seed}.csv"

    for i in range(0, 100):
        git_clean(kernel_src)
        prob = 50

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
        save_to_csv(csv_file_path, seed, prob, output_config_path, csvname_seed)

    return generated_config_files, csv_file_path


def git_checkout_commit(kernel_src: str, commit_hash: str):
    """
    This function checks out to a commit hash in the git repository
    Args:
    kernel_src: path to the kernel source
    commit_hash: commit hash to checkout to
    """
    repo = git.Repo(kernel_src)
    repo.git.checkout(commit_hash)
    return repo.head.commit.hexsha


def compile_kernel(
    kernel_src_list, generated_config_files, output_dir, commit_hash, csv_file_path
) -> list:
    """
    This function compiles the kernel with the generated configuration files
    It first git cleans the kernel source, then checks out to the commit hash
    Then it builds the kernel with the generated configuration files
    Args:
    kernel_src_list: list of kernel source paths
    generated_config_files: list of generated configuration files
    output_dir: output directory
    commit_hash: commit hash to checkout to
    csv_file_path: path to the csv file
    Returns: list of configuration files that failed to compile
    """
    config_not_compiled = []
    bzimage_paths = []

    for kernel_src, config_file in zip(kernel_src_list, generated_config_files):
        git_clean(kernel_src)
        # logging.debug(f"counter: {counter}")
        head_commit = git_checkout_commit(kernel_src, commit_hash)
        logging.debug(f"HEAD commit: {head_commit}")

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
            logging.debug("Output of kernel compilation:")
            logging.debug(result.stdout)

            if result.returncode != 0:
                logging.error(result.stderr)
            else:
                add_to_csv(csv_file_path, config_file, "Compiled", True)
                bzimage_save_dir = (
                    f"{output_dir}/{os.path.basename(config_file)}.bzImage"
                )
                bzimage_path = f"{kernel_src}/arch/x86/boot/bzImage"
                bzimage_paths.append(bzimage_save_dir)
                try:
                    shutil.copy(bzimage_path, bzimage_save_dir)
                except shutil.Error as e:
                    logging.error(e)

        except subprocess.CalledProcessError as e:
            logging.error(e)
            config_not_compiled.append(config_file)
            add_to_csv(csv_file_path, config_file, "Compiled", False)
            add_to_csv(csv_file_path, config_file, "Booted", False)

    # if len(config_not_compiled) > 0:
    #     logging.error(f"Config files that failed to compile: {config_not_compiled}")

    return bzimage_paths


def run_qemu(bzimage_paths, output_dir, csv_file_path):
    """
    This function runs the bzImage files in qemu
    Args:
    bzimage_paths: list of paths to the bzImage files
    """
    for bzimage_path in bzimage_paths:
        logname = f"{output_dir}/{os.path.basename(bzimage_path)}.log"
        pidname = f"{output_dir}{os.path.basename(bzimage_path)}.pid"
        config_path = logname.replace(".bzImage.log", "")

        command = [
            "qemu-system-x86_64",
            "-m",
            "2G",
            "-smp",
            "2",
            "-kernel",
            bzimage_path,
            "-append",
            "console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0",
            "-drive",
            "file=/home/sanan/debian_image/bullseye.img,format=raw",
            "-net",
            "user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:10021-:22",
            "-net",
            "nic,model=e1000",
            "-enable-kvm",
            "-nographic",
            "-pidfile",
            pidname,
            "-s",
        ]

        logging.debug(f"Running qemu with bzImage: {bzimage_path}")
        logfile = open(logname, "w")
        qemu_process = subprocess.Popen(
            command, stdout=logfile, stderr=subprocess.STDOUT
        )

        time.sleep(200)
        booted = False
        with open(logname, "r") as logfile:
            for line in logfile:
                if "syzkaller login:" in line:
                    logging.debug("Qemu booted successfully")
                    booted = True

        logfile.close()
        unbootable_images = []
        if not booted:
            logging.error(f"Qemu failed to boot with bzImage: {bzimage_path}")
            unbootable_images.append(bzimage_path)
            # qemu_process.kill()
            add_to_csv(csv_file_path, config_path, "Booted", False)
            logging.debug(f"Qemu process id inside if: {qemu_process.pid}")
            os.kill(qemu_process.pid, signal.SIGKILL)
        else:
            os.kill(qemu_process.pid, signal.SIGKILL)
            add_to_csv(csv_file_path, config_path, "Booted", True)



def main():
    args = parse_args()

    loglevel = args.verbose
    numeric_level = getattr(logging, loglevel.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError("Invalid log level: %s" % loglevel)
    logging.basicConfig(level=loglevel)

    generated_config_files = generate_randconfigs(args.kernel_src, args.output_dir)
    logging.debug(generated_config_files)

    kernel_src_list = ["/home/sanan/linux-next" for i in range(100)]
    bzimage_paths = compile_kernel(
        kernel_src_list, generated_config_files, args.output_dir, args.gitref
    )

    logging.debug("Bzimage paths:")
    logging.debug(bzimage_paths)

    run_qemu(bzimage_paths, args.output_dir)


if __name__ == "__main__":
    main()
