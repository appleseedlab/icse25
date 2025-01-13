from pathlib import Path
import json
import time
from dataclasses import dataclass
import subprocess
from typing import Optional
from git import Repo
import shutil
from loguru import logger
import argparse
import socket
from tempfile import NamedTemporaryFile, TemporaryDirectory
from concurrent.futures import ProcessPoolExecutor, as_completed
from tqdm import tqdm


@dataclass
class Config:
    kernel_src: Path = Path()
    kernel_commit_1: str = ""
    kernel_commit_2: str = ""
    path_config_default: Path = Path()
    path_config_repaired: Path = Path()
    path_reproducer: Path = Path()
    output: Path = Path("./output")
    debian_image_src: Path = Path()
    cores: int = 1


@dataclass
class QemuInstance:
    pid: int = 0
    ssh_port: int = 0
    log_path: Path = Path()
    pid_path: Path = Path()


@dataclass
class DebianImage:
    path_debian_image: Path = Path()
    path_debian_image_key: Path = Path()


def parse_config(config_file: Path) -> Config:
    with open(config_file, "r") as cf:
        json_config = json.load(cf)

    return Config(
        json_config["kernel_src"],
        json_config["kernel_commit_1"],
        json_config["kernel_commit_2"],
        json_config["path_config_default"],
        json_config["path_config_repaired"],
        json_config["path_reproducer"],
        json_config["output"],
        json_config["debian_image_src"],
        json_config["cores"],
    )


def compile_kernel(
    kernel_src: Path, kernel_commit: str, config_file: Path, cores: int, output: Path
) -> tuple[bool, Optional[Path], Optional[Path]]:
    repo = Repo(kernel_src)

    path_bzImage = output / "bzImage"
    path_vmlinux = output / "vmlinux"

    try:
        repo.git.clean("-xdf")
        repo.git.reset("--hard")
        repo.git.checkout(kernel_commit)
        subprocess.run(["make", "-C", kernel_src, "defconfig"])
        shutil.copy(config_file, kernel_src / ".config")
        subprocess.run(["make", "-C", kernel_src, "olddefconfig"])
        subprocess.run(["make", "-C", kernel_src, f"-j{cores}"])
    except Exception as e:
        logger.error(f"Error compiling kernel: {e}")
        return False, None, None

    try:
        shutil.copy(kernel_src / "arch/x86/boot/bzImage", path_bzImage)
        shutil.copy(kernel_src / "vmlinux", path_vmlinux)
    except Exception as e:
        logger.error(f"Error copying kernel image: {e}")
        return False, None, None

    return True, path_bzImage, path_vmlinux


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compile kernel")
    parser.add_argument(
        "-c",
        "--config_file",
        type=Path,
        required=True,
        help="Path to the config file",
    )

    return parser.parse_args()


def get_free_port() -> int:
    """Get a random free port via asking the OS to allocate one"""

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(("localhost", 0))
            port = s.getsockname()[1]
    except OSError as e:
        logger.error(f"Failed to get a free port: {e}")
        raise SystemExit(44)

    return port


def run_qemu(
    kernel_image_path: Path, debian_image_path: Path, qemu_instance: QemuInstance
) -> bool:
    """Check if a kernel image is bootable using QEMU.

    The function starts a QEMU instance with the given kernel image and a Debian image.
    It polls the log file every second for the given timeout period.
    It then checks the QEMU log file for the "syzkaller login:" string, which indicates
    that the kernel booted successfully.

    Args:
        kernel_image_path (Path): path to the kernel image
        debian_image_path (Path): path to the Debian image

    Returns:
        bool: True if the kernel image is bootable, False otherwise

    """
    qemu_instance.log_path = Path(kernel_image_path.parent, "qemu.log")
    qemu_instance.log_path.touch()

    qemu_instance.pid_path = Path(kernel_image_path.parent, "vm.pid")
    qemu_instance.pid_path.touch()

    logger.debug(f"QEMU log path: {qemu_instance.log_path}")

    qemu_instance.ssh_port = get_free_port()

    # create copy of debian image to prevent deadlocks when running multiple
    # qemu instances
    with NamedTemporaryFile(delete=False, suffix=".img") as temp_debian:
        shutil.copyfile(debian_image_path, temp_debian.name)
        debian_image_path = Path(temp_debian.name)

    logger.debug(f"Temporary debian image path: {debian_image_path}")

    command = (
        f"qemu-system-x86_64 "
        f"-m 2G "
        f"-smp 2 "
        f"-kernel {str(kernel_image_path)} "
        f"-append 'console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0' "
        f"-drive file={str(debian_image_path)},format=raw "
        f"-net user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:{str(qemu_instance.ssh_port)}-:22 "
        f"-net nic,model=e1000 "
        f"-enable-kvm "
        f"-nographic "
        f"-pidfile {str(qemu_instance.pid_path)} "
        f"-serial file:{str(qemu_instance.log_path)} &"
    )

    # Extract qemu vm pid
    with open(qemu_instance.pid_path, "r") as pid_file:
        qemu_instance.pid = int(pid_file.read().strip())

    try:
        logger.debug(f"Command to be executed: {command}")
        with open(qemu_instance.log_path, "w") as log_file:
            subprocess.run(
                command,
                shell=True,
                stdout=log_file,
                stderr=log_file,
            )

    except Exception as e:
        logger.error(f"Error: {e}")
        return False

    return False


def cleanup_temporary_resources(temporary_resources: list[Path]):
    """Clean up temporary resources created for performing some operations"""
    with tqdm(total=len(temporary_resources)) as pbar:
        with ProcessPoolExecutor() as executor:
            futures = {
                executor.submit(shutil.rmtree, resource, ignore_errors=True): resource
                for resource in temporary_resources
            }

            for future in as_completed(futures):
                try:
                    future.result()
                    pbar.update(1)
                except Exception as e:
                    logger.error(f"Failed to clean up temporary resource: {e}")


def terminate_qemu_procs(qemu_pids: list[int]):
    if not qemu_pids:
        logger.error("No QEMU processes to terminate")
        return

    for qemu_pid in qemu_pids:
        try:
            subprocess.run(["kill", "-9", str(qemu_pid)])
        except Exception as e:
            logger.error(f"Error terminating QEMU process: {e}")


def compile_reproducer(path_reproducer: Path, output: Path):
    # Compile reproducer C file
    try:
        subprocess.run(["gcc", "-o", "reproducer", path_reproducer])
    except Exception as e:
        raise ValueError(f"Error compiling reproducer: {e}")

    path_reproducer_bin = output / "reproducer"
    shutil.move("reproducer", path_reproducer_bin)


def upload_reproducer_to_vms(
    path_reproducer_bin: Path, path_debian_image_key: Path, qemu_ssh_port: int
):
    try:
        subprocess.run(
            [
                "scp",
                "-i",
                path_debian_image_key,
                "-p",
                str(qemu_ssh_port),
                "-o",
                "StrictHostKeyChecking no",
                str(path_reproducer_bin),
                "root@localhost:/root",
            ]
        )
    except Exception as e:
        raise ValueError(f"Error uploading reproducer to VM: {e}")


def execute_reproducer_on_vms(
    path_debian_image_key: Path, qemu_ssh_port: int
):
    try:
        subprocess.run(
            [
                "ssh",
                "-i",
                path_debian_image_key,
                "-p",
                str(qemu_ssh_port),
                "-o",
                "StrictHostKeyChecking no",
                "root@localhost",
                "./reproducer",
            ]
        )
    except Exception as e:
        raise ValueError(f"Error executing reproducer on VM: {e}")

def vm_crash_check(qemu_log_path: Path) -> bool:
    """Check if a VM crashed by looking at the QEMU log file.

    Args:
        qemu_log_path (Path): path to the QEMU log file

    Returns:
        bool: True if the VM crashed, False otherwise

    """
    with open(qemu_log_path, "r") as log_file:
        log_content = log_file.read()

    return "Kernel panic" in log_content

def main():
    args = parse_args()

    if not args.config_file.exists():
        logger.error("Config file does not exist")
        return

    config = parse_config(args.config_file)

    # clone kernel source into a temporary directory
    tmp_kernel_src = TemporaryDirectory()
    Repo.clone_from(config.kernel_src, tmp_kernel_src.name)

    commits = [config.kernel_commit_1, config.kernel_commit_2]
    configs = [config.path_config_default, config.path_config_repaired]

    kernel_image_paths: list[Path] = []
    qemu_instances: list[QemuInstance] = []
    debian_image = DebianImage(
        path_debian_image=config.debian_image_src / "bullseye.img",
        path_debian_image_key=config.debian_image_src / "bullseye.id_rsa",
    )

    try:
        for commit, config_file in zip(commits, configs):
            compilation_res, kernel_image_path, vmlinux_path = compile_kernel(
                Path(tmp_kernel_src.name),
                commit,
                config_file,
                config.cores,
                config.output,
            )
            if not compilation_res:
                logger.error("Error compiling kernel")
                return
            if kernel_image_path is not None:
                kernel_image_paths.append(kernel_image_path)

        logger.info("Kernel compiled successfully")

        for kernel_image_path in kernel_image_paths:
            qemu_instance = QemuInstance()
            boot_res = run_qemu(
                kernel_image_path, debian_image.path_debian_image, qemu_instance
            )
            if not boot_res:
                logger.error("Error booting kernel")
                return
            qemu_instances.append(qemu_instance)

        logger.info(
            f"Started QEMU instances with pids: {[qemu_instance.pid for qemu_instance in qemu_instances]}"
        )

        compile_reproducer(config.path_reproducer, config.output)

        logger.info("Reproducer compiled successfully")

        for qemu_instance in qemu_instances:
            upload_reproducer_to_vms(
                config.output / "reproducer", debian_image.path_debian_image_key, qemu_instance.ssh_port
            )
            logger.info("Reproducer uploaded to VM")
            execute_reproducer_on_vms(
                debian_image.path_debian_image_key, qemu_instance.ssh_port
            )
            logger.info("Reproducer executed on VM")
            # wait for reproducer to execute
            time.sleep(20)
            if vm_crash_check(qemu_instance.log_path):
                logger.info("VM crashed")
            else:
                logger.info("VM did not crash")

    except Exception as e:
        logger.error(f"Error: {e}")
        cleanup_temporary_resources([Path(tmp_kernel_src.name), *kernel_image_paths])
        terminate_qemu_procs([qemu_instance.pid for qemu_instance in qemu_instances])


if __name__ == "__main__":
    main()
