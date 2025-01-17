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
import threading
from uuid import uuid4
import os
import signal
import csv
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

@dataclass
class Config:
    kernel_src: Path = Path()
    kernel_commit_id: str = ""
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


# def parse_config(config_file: Path) -> Config:
#     with open(config_file, "r") as cf:
#         json_config = json.load(cf)

#     return Config(
#         json_config["kernel_src"],
#         json_config["kernel_commit_id"],
#         json_config["path_config_default"],
#         json_config["path_config_repaired"],
#         json_config["path_reproducer"],
#         json_config["output"],
#         json_config["debian_image_src"],
#         json_config["cores"],
#     )

def parse_config(config_file: Path) -> Config:
    with open(config_file, "r") as cf:
        json_config = json.load(cf)

    return Config(
        kernel_src=Path(json_config["kernel_src"]),
        kernel_commit_id=json_config["kernel_commit_id"],
        path_config_default=Path(json_config["path_config_default"]),
        path_config_repaired=Path(json_config["path_config_repaired"]),
        path_reproducer=Path(json_config["path_reproducer"]),
        output=Path(json_config["output"]),
        debian_image_src=Path(json_config["debian_image_src"]),
        cores=json_config["cores"],
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
        
        # Skip the checkout if no commit is provided
        if kernel_commit:
            logger.debug(f"Checking out commit: {kernel_commit}")
            repo.git.checkout(kernel_commit)

        # Make the directory if it doesn't exist
        if not config_file.parent.exists():
            logger.info(f"Creating directory: {config_file.parent}")
            config_file.parent.mkdir(parents=True, exist_ok=True)
            
         # Compile the kernel
        # Step 1: Generate a default configuration
        try:
            subprocess.run(
                ["make", "-C", str(kernel_src), "defconfig"],
                check=True)
        except Exception as e:
            logger.error(f"make defconfig failed with the exception: ", {e})
        # Step 2: Update the .config file with Syzkaller options
        config_path = kernel_src / ".config"
        with open(config_path, "a") as cf:
            logger.info("Adding Syzkaller config options to .config")
            cf.write(
                "\n".join([
                    "# Syzkaller config options",
                    "CONFIG_KCOV=y",
                    "CONFIG_DEBUG_INFO_DWARF4=y",
                    "CONFIG_KASAN=y",
                    "CONFIG_KASAN_INLINE=y",
                    "CONFIG_CONFIGFS_FS=y",
                    "CONFIG_SECURITYFS=y",
                    "CONFIG_CMDLINE_BOOL=y",
                    'CONFIG_CMDLINE="net.ifnames=0"'
                    ""
                ])
            )

        # Step 3: Save the modified .config to the target path
        shutil.copy(config_path, config_file)  # Save the modified config to the desired location

        # Step 4: Regenerate dependencies based on the updated .config
        try:
            subprocess.run(["make", "-C", kernel_src, "olddefconfig"])
        except Exception as e:
            logger.error(f"make olddefconfig failed with the exception: ", {e})
            
        try:
            subprocess.run(["make", "-C", kernel_src, f"-j{cores}"])
        except Exception as e:
            logger.error(f"make failed with the exception: ", {e})
            
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
    kernel_image_path: Path,
    debian_image_path: Path,
    qemu_instance: QemuInstance,
    timeout: int = 300,
    commit_id: str = "",
    config_type: str = "default config",
) -> bool:
    """
    Runs a QEMU instance with a kernel image and a Debian image, ensuring it terminates after the specified timeout.

    Args:
        kernel_image_path (Path): Path to the kernel image.
        debian_image_path (Path): Path to the Debian image.
        qemu_instance (QemuInstance): Instance to store QEMU details.
        timeout (int): Timeout in seconds. Defaults to 300 seconds (5 minutes).
        commit_id (str): Commit ID being tested.
        config_type (str): Type of config being used (default or repaired).

    Returns:
        bool: True if QEMU starts successfully, False otherwise.
    """
    qemu_instance.log_path = Path(kernel_image_path.parent, "qemu.log")
    qemu_instance.log_path.touch()

    qemu_instance.pid_path = Path(kernel_image_path.parent, f"vm_{uuid4().hex}.pid")
    if qemu_instance.pid_path.exists():
        logger.warning(f"PID file {qemu_instance.pid_path} exists. Deleting it to avoid conflicts.")
        qemu_instance.pid_path.unlink()

    logger.debug(f"QEMU log path: {qemu_instance.log_path}")
    qemu_instance.ssh_port = get_free_port()

    # Create a temporary Debian image copy
    with NamedTemporaryFile(delete=False, suffix=".img") as temp_debian:
        shutil.copyfile(debian_image_path, temp_debian.name)
        debian_image_path = Path(temp_debian.name)

    logger.debug(f"Temporary Debian image path: {debian_image_path}")

    command = (
        f"qemu-system-x86_64 "
        f"-m 2G "
        f"-smp 2 "
        f"-kernel {str(kernel_image_path)} "
        f"-append 'console=ttyS0 root=/dev/sda rw earlyprintk=serial net.ifnames=0' "
        f"-drive file={str(debian_image_path)},format=raw "
        f"-net user,hostfwd=tcp:127.0.0.1:{str(qemu_instance.ssh_port)}-:22 "
        f"-net nic,model=e1000 "
        f"-enable-kvm "
        f"-nographic "
        f"-pidfile {str(qemu_instance.pid_path)} "
        f"-serial file:{str(qemu_instance.log_path)}"
    )

    try:
        logger.debug(f"QEMU command: {command}")
        process = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        # Wait for the PID file to be created and read the PID
        for _ in range(10):  # Wait up to 10 seconds
            if qemu_instance.pid_path.exists() and qemu_instance.pid_path.read_text().strip():
                qemu_instance.pid = int(qemu_instance.pid_path.read_text().strip())
                logger.info(f"QEMU PID: {qemu_instance.pid}")
                break
            time.sleep(1)
        else:
            logger.error("PID file not created or empty. Unable to monitor QEMU process.")
            process.kill()
            return False

        # Watchdog Handler to Monitor Log File
        class VMLogHandler(FileSystemEventHandler):
            def __init__(self, qemu_instance, timeout, csv_path, commit_id, config_type):
                self.qemu_instance = qemu_instance
                self.timeout = timeout
                self.csv_path = csv_path
                self.commit_id = commit_id
                self.config_type = config_type
                self.start_time = time.time()
                self.success = False

            def on_modified(self, event):
                if event.src_path == str(self.qemu_instance.log_path):
                    self.check_vm_state()

            def check_vm_state(self):
                try:
                    with open(self.qemu_instance.log_path, "r") as log_file:
                        for line in log_file:
                            if "login:" in line or "Welcome to" in line:
                                logger.info("VM booted successfully!")
                                self.success = True
                                reproducer_output = run_reproducer(self.qemu_instance, self.qemu_instance.ssh_port)
                                self.terminate_vm("booted", reproducer_output)
                                return
                            elif "Kernel panic" in line or "Error" in line:
                                logger.error("VM crashed or encountered an error.")
                                self.terminate_vm("failed")
                                return
                except Exception as e:
                    logger.error(f"Error reading log file: {e}")

            def terminate_vm(self, result, reproducer_output=None):
                logger.info(f"Terminating VM with PID: {self.qemu_instance.pid}")
                if self.qemu_instance.pid:
                    try:
                        os.kill(self.qemu_instance.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        logger.warning(f"Process with PID {self.qemu_instance.pid} already terminated.")
                self.append_csv(result, reproducer_output)
                observer.stop()

            def append_csv(self, result, reproducer_output=None):
                csv_path = Path(self.csv_path)
                header = ["commit_id", "config", "result", "reproducer_output"]
                file_exists = csv_path.exists()
                with open(csv_path, "a", newline="") as csvfile:
                    writer = csv.writer(csvfile)
                    if not file_exists:
                        writer.writerow(header)
                    writer.writerow([self.commit_id, self.config_type, result, reproducer_output or "N/A"])

        # Set up watchdog observer
        observer = Observer()
        event_handler = VMLogHandler(
            qemu_instance,
            timeout,
            "/home/eshgin/Desktop/experiments/new_icse/get_results_output/pass_fail.csv",
            commit_id,
            config_type,
        )
        observer.schedule(event_handler, str(qemu_instance.log_path.parent), recursive=False)
        observer.start()

        # Monitor the VM process for the specified timeout
        while time.time() - event_handler.start_time < timeout:
            if not observer.is_alive():
                break
            time.sleep(5)

        # If timeout expires without success
        if not event_handler.success:
            logger.warning("Timeout expired: VM did not boot successfully.")
            event_handler.terminate_vm("failed")

    except Exception as e:
        logger.error(f"Error starting QEMU: {e}")
        return False

    return True


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


# def terminate_qemu_procs(qemu_pids: list[int]):
#     if not qemu_pids:
#         logger.warning("No QEMU processes to terminate")
#         return

#     for qemu_pid in qemu_pids:
#         try:
#             logger.info(f"Terminating QEMU process and children with PID: {qemu_pid}")
#             subprocess.run(["pkill", "-P", str(qemu_pid)])  # Terminate all child processes
#             subprocess.run(["kill", "-9", str(qemu_pid)])  # Terminate the parent process
#         except Exception as e:
#             logger.error(f"Error terminating QEMU process with PID {qemu_pid}: {e}")


def run_reproducer(qemu_instance: QemuInstance, ssh_port: int) -> Optional[str]:
    """
    Transfers, compiles, and runs the reproducer inside the VM.

    Args:
        qemu_instance (QemuInstance): The QEMU instance being monitored.
        ssh_port (int): The SSH port for accessing the VM.

    Returns:
        Optional[str]: The output of the reproducer run, or None if it fails.
    """
    logger.info("Transferring, compiling, and running reproducer in the VM...")
    try:
        reproducer_src = "/home/eshgin/Desktop/experiments/new_icse/icse25/hello_world.c"
        remote_path = "/root/hello_world.c"
        ssh_key = "/home/eshgin/Desktop/debian_image/bullseye.id_rsa"  # Use the correct private key
        
        # Step 1: Transfer the reproducer source file to the VM
        logger.info(f"Transferring {reproducer_src} to the VM at {remote_path}...")
        subprocess.run(
            [
                "scp",
                "-i", ssh_key,
                "-P", str(ssh_port),
                "-o", "StrictHostKeyChecking=no",
                reproducer_src,
                f"root@localhost:{remote_path}",
            ],
            check=True,
        )
        logger.info("Reproducer source file transferred successfully.")

        # Step 2: Compile the reproducer inside the VM
        logger.info("Compiling the reproducer inside the VM...")
        compile_command = f"gcc -o /root/reproducer {remote_path}"
        subprocess.run(
            [
                "ssh",
                "-i", ssh_key,
                "-p", str(ssh_port),
                "-o", "StrictHostKeyChecking=no",
                "root@localhost",
                compile_command,
            ],
            check=True,
        )
        logger.info("Reproducer compiled successfully inside the VM.")

        # Step 3: Run the compiled reproducer inside the VM
        logger.info("Running the reproducer inside the VM...")
        run_command = "./reproducer"
        result = subprocess.run(
            [
                "ssh",
                "-i", ssh_key,
                "-p", str(ssh_port),
                "-o", "StrictHostKeyChecking=no",
                "root@localhost",
                run_command,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        logger.info(f"Reproducer output:\n{result.stdout}")
        return result.stdout

    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to run reproducer in the VM: {e}")
        return None


# def upload_reproducer_to_vms(
#     path_reproducer_bin: Path, path_debian_image_key: Path, qemu_ssh_port: int
# ):
#     try:
#         subprocess.run(
#             [
#                 "scp",
#                 "-i",
#                 path_debian_image_key,
#                 "-p",
#                 str(qemu_ssh_port),
#                 "-o",
#                 "StrictHostKeyChecking no",
#                 str(path_reproducer_bin),
#                 "root@localhost:/root",
#             ]
#         )
#     except Exception as e:
#         raise ValueError(f"Error uploading reproducer to VM: {e}")


# def execute_reproducer_on_vms(
#     path_debian_image_key: Path, qemu_ssh_port: int
# ):
#     try:
#         subprocess.run(
#             [
#                 "ssh",
#                 "-i",
#                 path_debian_image_key,
#                 "-p",
#                 str(qemu_ssh_port),
#                 "-o",
#                 "StrictHostKeyChecking no",
#                 "root@localhost",
#                 "./reproducer",
#             ]
#         )
#     except Exception as e:
#         raise ValueError(f"Error executing reproducer on VM: {e}")

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

    # Clone kernel source into a temporary directory
    tmp_kernel_src = TemporaryDirectory()
    Repo.clone_from(config.kernel_src, tmp_kernel_src.name, depth=1)
    
    commits = [config.kernel_commit_id]
    configs = [config.path_config_default, config.path_config_repaired]

    kernel_image_paths: list[Path] = []
    qemu_instances: list[QemuInstance] = []
    debian_image = DebianImage(
        path_debian_image=config.debian_image_src / "bullseye.img",
        path_debian_image_key=config.debian_image_src / "bullseye.id_rsa",
    )

    try:
        # Compile kernel for each commit and configuration
        for commit, config_file in zip(commits, configs):
            logger.info(f"Compiling kernel for commit: {commit} with config: {config_file}")
            compilation_res, kernel_image_path, vmlinux_path = compile_kernel(
                Path(tmp_kernel_src.name),
                commit,
                config_file,
                config.cores,
                config.output,
            )
            if not compilation_res:
                logger.error(f"Failed to compile kernel for commit: {commit}")
                return

            if kernel_image_path:
                kernel_image_paths.append(kernel_image_path)

        logger.info("Kernel compilation completed successfully.")

        # Run QEMU for each compiled kernel image
        for kernel_image_path in kernel_image_paths:
            logger.info(f"Starting QEMU with kernel image: {kernel_image_path}")
            qemu_instance = QemuInstance()
            boot_res = run_qemu(
                kernel_image_path, debian_image.path_debian_image, qemu_instance, timeout=300
            )
            if not boot_res:
                logger.error(f"Error booting QEMU with kernel image: {kernel_image_path}")
                return
            qemu_instances.append(qemu_instance)


        logger.info(
            f"Started QEMU instances with PIDs: {[qemu_instance.pid for qemu_instance in qemu_instances]}"
        )

        # Reproducer-related steps (optional, can be skipped)
        if config.path_reproducer.exists():
            compile_reproducer(config.path_reproducer, config.output)
            logger.info("Reproducer compiled successfully")

            for qemu_instance in qemu_instances:
                upload_reproducer_to_vms(
                    config.output / "reproducer",
                    debian_image.path_debian_image_key,
                    qemu_instance.ssh_port,
                )
                logger.info("Reproducer uploaded to VM")

                execute_reproducer_on_vms(
                    debian_image.path_debian_image_key, qemu_instance.ssh_port
                )
                logger.info("Reproducer executed on VM")
                # Wait for reproducer to execute
                time.sleep(20)

                # Check for crashes in the VM
                if vm_crash_check(qemu_instance.log_path):
                    logger.info(f"VM crashed while testing reproducer on PID: {qemu_instance.pid}")
                else:
                    logger.info(f"VM did not crash while testing reproducer on PID: {qemu_instance.pid}")
        else:
            logger.warning("No reproducer specified. Skipping reproducer steps.")

    except Exception as e:
        logger.error(f"Error: {e}")
    
    finally:
        cleanup_temporary_resources([Path(tmp_kernel_src.name), *kernel_image_paths])
        # terminate_qemu_procs([qemu_instance.pid for qemu_instance in qemu_instances if qemu_instance.pid])

if __name__ == "__main__":
    main()


