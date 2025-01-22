import argparse
import subprocess
import threading
import logging
import time
import shutil
import git
import git.exc
import os
import csv
import signal
from tqdm import tqdm
from concurrent.futures import ProcessPoolExecutor, as_completed
from git import Repo
from pathlib import Path
import tempfile
from tempfile import TemporaryDirectory
from loguru import logger

from gitdb.util import sys

def get_repo_root():
    try:
        # Use 'git rev-parse --show-toplevel' to get the repo root
        repo_root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,  # Suppress errors if not in a Git repo
            text=True,  # Return output as a string
        ).strip()  # Remove trailing newlines or spaces
        return Path(repo_root)
    except subprocess.CalledProcessError:
        # Not in a Git repository
        return None

def parse_args():
    """
    This function parses the command line arguments and returns them
    Returns: parsed arguments
    """
    script_dir = os.path.dirname(os.path.realpath(__file__))
    # get the full path of the script's repository
    repo_root = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))

    if not repo_root:
        raise Exception("Not in a git repository")

    parser = argparse.ArgumentParser(
        description="Generate random configurations for the kernel"
    )
    parser.add_argument(
        "-k",
        "--kernel_src",
        type=str,
        default=Path(repo_root) / "linux-next",
        help="Path to the kernel source directory",
    )
    parser.add_argument(
        "-di",
        "--debian_image",
        type=str,
        default=Path(repo_root) / "debian_image/bullseye.img",
        help="Path to the debian image",
    )
    parser.add_argument(
        "-qt",
        "--qemu_timeout",
        type=int,
        default=300,
        help="Timeout for qemu to boot the kernel",
    )
    parser.add_argument(
        "-w",
        "--workers",
        type=int,
        default=max(1, os.cpu_count() - 1),
        help="Number of workers to clone kernels in parallel",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Verbose mode",
    )

    parser.add_argument(
        "-o",
        "--output_dir",
        type=str,
        default=Path(script_dir) / "outdir/",
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


def generate_randconfigs(kernel_src, output_dir) -> tuple[list, Path]:
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

    csv_file_path = Path(output_dir).joinpath(f"randconfig_experiment_results_{csvname_seed}.csv")

    for _ in range(0, 100):
        git_clean(kernel_src)
        prob = 50

        seed = int(time.time())
        command = f"KCONFIG_SEED={seed} KCONFIG_PROBABILTIY={prob} make randconfig"
        logging.debug(f"Seed: {seed}, Probability: {prob}")

        output_config_path = Path(f"{output_dir}/{seed}_{prob}.config").resolve()
        try:
            result = subprocess.run(
                command, shell=True, cwd=kernel_src, check=True, capture_output=True
            )
            logging.debug(result.stdout)

        except Exception as e:
            logging.error(e)

        logging.debug(f"Copying config file from {config_path} to {output_config_path}")
        try:
            shutil.copy(config_path, output_config_path)
        except Exception as e:
            logging.error(f"Falied to copy config file: {e}")
            logging.error("make randconfig must have failed")

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

    csv_file_path = csv_file_path.resolve()
    csv_file_path.touch()
    makenproc_log = f"{output_dir}/makenproc.log"
    logger.debug(f"compilation logs are saved in {makenproc_log}")

    for kernel_src, config_file in zip(kernel_src_list, generated_config_files):
        git_clean(kernel_src)
        # logging.debug(f"counter: {counter}")
        head_commit = git_checkout_commit(kernel_src, commit_hash)
        logger.debug(f"HEAD commit: {head_commit}")

        config_file = Path(config_file).resolve()
        logger.debug(f"Working on config file: {config_file}")
        subprocess.run(f"KCONFIG_CONFIG={config_file} make -C {kernel_src} olddefconfig", shell=True, cwd=kernel_src)
        command = f"KCONFIG_CONFIG={config_file} make -C {kernel_src} -j$(nproc)"
        try:
            with open(makenproc_log, "w") as log:
                result = subprocess.run(
                    command,
                    shell=True,
                    cwd=kernel_src,
                    check=True,
                    text=True,
                    stdout=log,
                    stderr=log,
                )
            logger.debug("Output of kernel compilation:")
            logger.debug(result.stdout)

            if result.returncode != 0:
                logger.error(result.stderr)
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
                    logger.error(e)

        except subprocess.CalledProcessError as e:
            logger.error(e)
            config_not_compiled.append(config_file)
            add_to_csv(csv_file_path, config_file, "Compiled", False)
            add_to_csv(csv_file_path, config_file, "Booted", False)

    # if len(config_not_compiled) > 0:
    #     logging.error(f"Config files that failed to compile: {config_not_compiled}")

    return bzimage_paths


def run_qemu(bzimage_paths, debian_image, timeout, output_dir, csv_file_path):
    """
    This function runs the bzImage files in qemu

    Args:
        bzimage_paths: list of paths to the bzImage files
        debian_image: path to the debian image
        timeout: timeout for qemu to boot the kernel
        output_dir: output directory
        csv_file_path: path to the csv file
    """
    for bzimage_path in bzimage_paths:
        logname = f"{output_dir}/{os.path.basename(bzimage_path)}.log"
        pidname = f"{output_dir}{os.path.basename(bzimage_path)}.pid"
        config_path = logname.replace(".bzImage.log", "")
        config_path = Path(config_path).resolve()

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
            f"file={debian_image},format=raw",
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

        time.sleep(timeout)
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

    logger.debug("Finished bootability testing for the provided images")


def add_to_csv(csv_file_path, config_path, state, bootable):
    with open(csv_file_path, "r") as csv_file:
        csvreader = csv.DictReader(csv_file)
        fieldnames = csvreader.fieldnames
        data = [row for row in csvreader]

    if fieldnames is None:
        fieldnames = ["Seed", "Probability", "Config Path", "Compiled", "Booted"]

    for row in data:
        row_config_path = row["Config Path"]
        logger.debug(f"row_config_path: {row_config_path}")
        logger.debug(f"config_path: {config_path}")
        if row["Config Path"] == str(config_path):
            if state == "Compiled":
                row["Compiled"] = bootable
            elif state == "Booted":
                row["Booted"] = bootable

    with open(csv_file_path, "w") as csv_file:
        csvwriter = csv.DictWriter(csv_file, fieldnames=fieldnames)
        csvwriter.writeheader()
        csvwriter.writerows(data)

def check_args(args):
    """
    This function checks if the provided kernel source directory is valid
    Args:
    args: parsed arguments
    Raises: Exception
    """

    if not os.path.exists(args.kernel_src):
        raise Exception("Kernel source directory does not exist")

    # check if the kernel source directory is a git repository
    if not os.path.exists(f"{args.kernel_src}/.git"):
        raise Exception("Kernel source directory is not a git repository")

    # check if the provided git reference exists in the repository
    repo = git.Repo(args.kernel_src)
    try:
        repo.git.rev_parse(args.gitref)
    except git.exc.GitCommandError:
        raise Exception("Git reference does not exist in the repository")

    # create the output directory if it does not exist
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)

def clone_kernel(kernel_url, tmpdir, idx: int) -> Path:
    KERNEL_DIR = Path(f"{tmpdir}/linux-next-{idx}")
    KERNEL_DIR.mkdir(parents=True)

    try:
        Repo.clone_from(kernel_url, KERNEL_DIR)
    except Exception as e:
        logger.exception(f"Failed to clone kernel {idx}: {e}")

    # KERNEL_DIR = Path(f"{tmpdir}/linux-next-{idx}")
    # Repo.clone_from(kernel_url, KERNEL_DIR)
    return KERNEL_DIR

def copy_kernel(kernel_src: Path) -> Path:
    # create a temporary directory to store the cloned kernel
    thread_id = threading.get_ident()
    tmp_kernel_dir = tempfile.mkdtemp(prefix=f"kernel-{thread_id}-")
    tmp_kernel_repo = Repo.clone_from(kernel_src, tmp_kernel_dir)
    return Path(tmp_kernel_repo.working_dir)

def copy_kernel_in_parallel(kernel_src: Path, available_cores: int) -> list[Path]:
    kernel_dirs = []
    with tqdm(total=available_cores) as pbar:
        with ProcessPoolExecutor(max_workers=available_cores) as executor:
            futures = {
                executor.submit(copy_kernel, kernel_src)
                for _ in range(100)
            }

            for future in as_completed(futures):
                try:
                    kernel_dir = future.result()
                    kernel_dirs.append(kernel_dir)
                    pbar.update(1)
                    logger.debug(f"Finished processing kernel: {kernel_dir}")
                except Exception as e:
                    logger.exception(f"error when cloning: {e}")

    return kernel_dirs


def clone_kernels_parallel(available_cores: int) -> list[Path]:
    NUM_KERNELS = MAX_WORKERS = available_cores
    KERNEL_URL = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git"
    kernel_dirs = []

    logger.debug(f"Utilizing {MAX_WORKERS} workers to clone in parallel")
    with TemporaryDirectory() as tmpdir:
        with tqdm(total=NUM_KERNELS) as pbar:
            with ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:
                futures = {
                    executor.submit(clone_kernel, KERNEL_URL, tmpdir, i): i
                    for i in range(100)
                }

                for future in as_completed(futures):
                    try:
                        idx = future.result()
                        kernel_dirs.append(idx)
                        pbar.update(1)
                        logger.debug(f"Finished processing idx: {idx}")
                    except Exception as e:
                        logger.exception(f"error when cloning: {e}")

    return kernel_dirs

def set_logging_level(verbose):
    match verbose:
        case 1:
            logger.remove()
            logger.add(sys.stderr, level="ERROR")
        case 2:
            logger.remove()
            logger.add(sys.stderr, level="WARNING")
        case 3:
            logger.remove()
            logger.add(sys.stderr, level="DEBUG")

def main():
    args = parse_args()
    check_args(args)
    set_logging_level(args.verbose)

    logger.debug("Generating random configurations to compile kernel images")
    generated_config_files, csv_file_path = generate_randconfigs(
        args.kernel_src, args.output_dir
    )
    logger.debug(f"Generated random configs: {generated_config_files}")

    logger.debug("Cloning 100 kernel repositories in parallel")
    kernel_src_list = copy_kernel_in_parallel(args.kernel_src, args.workers)
    logger.debug(f"Cloned kernel sources: {kernel_src_list}")

    logger.debug("Compiling kernel images")
    bzimage_paths = compile_kernel(
        kernel_src_list,
        generated_config_files,
        args.output_dir,
        args.gitref,
        csv_file_path,
    )

    logging.debug("Bzimage paths:")
    logging.debug(bzimage_paths)

    run_qemu(bzimage_paths, args.debian_image, args.qemu_timeout, args.output_dir, csv_file_path)

    # delete the temporary kernel directories
    for kernel_dir in kernel_src_list:
        shutil.rmtree(kernel_dir)


if __name__ == "__main__":
    main()
