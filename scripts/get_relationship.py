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
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import glob

@dataclass
class Config:
    kernel_src: Path = Path()
    kernel_commit_id: str = ""
    path_config_default: Path = Path()
    path_config_repaired: Path = Path()
    default_config_image: Path = Path()
    repaired_config_image: Path = Path()
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
        kernel_src=Path(json_config["kernel_src"]),
        kernel_commit_id=json_config["kernel_commit_id"],
        path_config_default=Path(json_config["path_config_default"]),
        path_config_repaired=Path(json_config["path_config_repaired"]),
        default_config_image=Path(json_config["default_config_image"]),
        repaired_config_image=Path(json_config["repaired_config_image"]),
        path_reproducer=Path(json_config["path_reproducer"]),
        output=Path(json_config["output"]),
        debian_image_src=Path(json_config["debian_image_src"]),
        cores=json_config["cores"],
    )


def compile_kernel(
    kernel_src: Path, kernel_commit: str, config_file: Path, cores: int, output: Path
) -> tuple[bool, Optional[Path], Optional[Path]]:
    repo = Repo(kernel_src)

    # Define the paths for the kernel images
    path_bzImage = output / "bzImage"
    path_vmlinux = output / "vmlinux"

    try:
        # Reset and checkout the specified commit
        repo.git.clean("-xdf")
        repo.git.reset("--hard")
        if kernel_commit:
            logger.debug(f"Checking out commit: {kernel_commit}")
            repo.git.checkout(kernel_commit)

        # Ensure the output directory exists
        if not output.exists():
            logger.info(f"Creating output directory: {output}")
            output.mkdir(parents=True, exist_ok=True)

        # Step 1: Generate a default configuration
        try:
            subprocess.run(
                ["make", "-C", str(kernel_src), "defconfig"],
                check=True
            )
            logger.info("Default configuration generated successfully.")
        except subprocess.CalledProcessError as e:
            logger.error(f"make defconfig failed: {e}")
            return False, None, None
        # add make kvm_guest.config
        try:
            subprocess.run(
                ["make", "-C", str(kernel_src), "kvm_guest.config"],
                check=True
            )
            logger.info("kvm_guest.config applied successfully.")
        except subprocess.CalledProcessError as e:
            logger.error(f"make kvm_guest.config failed: {e}")
            return False, None, None
        
        # Step 2: Replace the .config with the provided config file
        config_path = kernel_src / ".config"
        
        # Check if the provided config file exists; create it if missing
        if not config_file.exists():
            raise FileNotFoundError("The config file is not present.")

        try:
            shutil.copy(config_file, config_path)
            logger.info(f".config replaced with content from {config_file}")
        except Exception as e:
            logger.error(f"Failed to replace .config: {e}")
            return False, None, None
        
        # Step 2.5: Add Syzkaller-specific configuration options to .config
        config_path = kernel_src / ".config"
        try:
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
                        'CONFIG_CMDLINE="net.ifnames=0"',
                        ""
                    ])
                )
        except Exception as e:
            logger.error(f"Failed to add Syzkaller config options: {e}")
            return False, None, None
        
        # Step 3: Regenerate dependencies based on the updated .config
        try:
            subprocess.run(["make", "-C", str(kernel_src), "olddefconfig"], check=True)
            logger.info("Dependencies regenerated with olddefconfig.")
        except subprocess.CalledProcessError as e:
            logger.error(f"make olddefconfig failed: {e}")
            return False, None, None

        # Step 4: Compile the kernel
        try:
            subprocess.run(["make", "-C", str(kernel_src), f"-j{cores}"], check=True)
            logger.info("Kernel compiled successfully.")
        except subprocess.CalledProcessError as e:
            logger.error(f"Kernel compilation failed: {e}")
            return False, None, None

        # Step 5: Copy the kernel images to the output directory
        try:
            bzImage_path = kernel_src / "arch/x86/boot/bzImage"
            vmlinux_path = kernel_src / "vmlinux"

            if not bzImage_path.exists():
                raise FileNotFoundError(f"bzImage not found at {bzImage_path}")
            if not vmlinux_path.exists():
                raise FileNotFoundError(f"vmlinux not found at {vmlinux_path}")

            shutil.copy(bzImage_path, path_bzImage)
            shutil.copy(vmlinux_path, path_vmlinux)
            logger.info("Kernel images copied successfully.")
        except FileNotFoundError as e:
            logger.error(f"Error copying kernel image: {e}")
            return False, None, None

    except Exception as e:
        logger.error(f"Error during kernel compilation: {e}")
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
    config_type: str = "",
    reproducer_src = "",
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
    icse_path="/home/eshgin/Desktop/experiments/new_icse"

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
                                shutil.copy(self.qemu_instance.log_path, f"{icse_path}/log_before_repro.log")
                                # Run the reproducer
                                time.sleep(10)
                                reproducer_output = run_reproducer(
                                    self.qemu_instance, self.qemu_instance.ssh_port, reproducer_src,
                                    config_type=config_type
                                )
                                logger.info(f"The result of the run is: {reproducer_output}")
                                time.sleep(10)
                                
                                # Check if reproducer output indicates success
                                if reproducer_output == "reproducer crashed the VM":
                                    logger.info(reproducer_output)
                                    self.success = True  # Update success flag
                                    self.terminate_vm("booted", reproducer_output)
                                elif reproducer_output == "timout":
                                    self.success = False
                                    logger.error(reproducer_output)
                                    self.terminate_vm("failed")
                                elif reproducer_output == "Reproducer did not affect VM":
                                    self.success = False
                                    self.terminate_vm("did not affect VM")
                                    logger.error(reproducer_output)
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
            f"{icse_path}/get_results_output/pass_fail.csv",
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

def run_reproducer(qemu_instance: QemuInstance, ssh_port: int, reproducer_src, config_type="default") -> Optional[str]:
    """
    Transfers, compiles, and runs the reproducer inside the VM.

    Args:
        qemu_instance (QemuInstance): The QEMU instance being monitored.
        ssh_port (int): The SSH port for accessing the VM.
        reproducer_src (str): Path to the reproducer source file.

    Returns:
        Optional[str]: The output of the reproducer run, or None if it fails.
    """
    icse_path="/home/eshgin/Desktop/experiments/new_icse"
    logger.info("Transferring, compiling, and running reproducer in the VM...")
    try:
        remote_dir = "/root/repro0"
        ssh_key = "/home/eshgin/Desktop/debian_image/bullseye.id_rsa"  # Use the correct private key

        # Step 1: Create remote directory
        try:
            mkdir_command = f'ssh -i {ssh_key} -p {ssh_port} -o UserKnownHostsFile=/dev/null  -o StrictHostKeyChecking=no  -o IdentitiesOnly=yes root@localhost "mkdir -p /root/repro0"'
            subprocess.run(
                mkdir_command,
                check=True,
                shell=True,
                capture_output=True,
                text=True
            )
        except Exception as e:
            logger.error(f"creating remote directory failed: {e}")
        logger.info(f"creating remote directory succeeded")

        # Step 2: Transfer binaries and reproducer to the VM
        logger.info(f"Transferring binaries and reproducer to {remote_dir}...")
        syzkaller_binaries = glob.glob(f"{icse_path}/syzkaller/bin/linux_amd64/*")
        scp_command = "scp -i {ssh_key} -P {ssh_port} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes /{binary} root@localhost:/root/repro0/"

        try:
            for binary in syzkaller_binaries:
                subprocess.run(
                    scp_command.format(binary=binary, ssh_key=ssh_key, ssh_port=ssh_port),
                    check=True,
                    shell=True,
                    capture_output=True,
                    text=True
                )
        except Exception as e:
            logger.error(f"Transferring binary files failed: {e}")
        logger.info("Binaries transferred successfully.")

        try:
            subprocess.run(
                scp_command.format(binary=reproducer_src, ssh_key=ssh_key, ssh_port=ssh_port),
                check=True,
                shell=True,
                capture_output=True,
                text=True
            )
        except Exception as e:
            logger.error(f"transferring reproducer failed: {e}")
        logger.info("Reproducer source file transferred successfully.")

        # Step 3: Ensure all files are executable
        logger.info("Making all binaries executable...")
        try:
            subprocess.run(
                [
                    "ssh",
                    "-i", ssh_key,
                    "-p", str(ssh_port),
                    "-o", "UserKnownHostsFile=/dev/null",
                    "-o", "StrictHostKeyChecking=no",
                    "-o", "IdentitiesOnly=yes",
                    "root@localhost",
                    f"chmod +x {remote_dir}/*",
                ],
                check=True,
                capture_output=True,
                text=True
            )
        except Exception as e:
            logger.error(f"changing modes of files failed: {e}")
        logger.info("changing modes of files succeeded.")
        # Step 4: Compile the reproducer inside the VM
        logger.info("Compiling the reproducer inside the VM...")
        try:
            compile_command = f"cd {remote_dir} && gcc -o repro_binary ./reproducer.c && ./repro_binary 2>&1 | tee /root/{config_type}.trace"
            res = subprocess.run(
                f'ssh -i {ssh_key} -p {ssh_port} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes root@localhost "{compile_command}"',
                shell=True,  # Use shell=True to interpret the command properly
                check=True,  # Raise an exception if the command fails
                capture_output=True,  # Capture stdout and stderr
                text=True,  # Decode stdout and stderr as text
                timeout=10,  # Optional timeout to prevent indefinite execution
            )

            logger.info("Reproducer compiled successfully inside the VM.")
            logger.info(f"Result of the run is: {res}")
            pull_scp_command = "scp -i {ssh_key} -P {ssh_port} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes root@localhost:/root/{config_type}.trace {icse_path}/get_results_output/trace_files"
            subprocess.run(
                    pull_scp_command.format(icse_path=icse_path, ssh_key=ssh_key, ssh_port=ssh_port, config_type=config_type),
                    check=True,
                    shell=True,
                    capture_output=True,
                    text=True
                )
            return "reproducer crashed the VM"
        except subprocess.CalledProcessError as e:
            logger.error(f"Compiling reproducer failed: {e.stderr.strip()}")
            
            try:
                pull_scp_command = "scp -i {ssh_key} -P {ssh_port} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes root@localhost:/root/{config_type}.trace {icse_path}/get_results_output/trace_files"
                subprocess.run(
                        pull_scp_command.format(icse_path=icse_path, ssh_key=ssh_key, ssh_port=ssh_port, config_type=config_type),
                        check=True,
                        shell=True,
                        capture_output=True,
                        text=True
                    )
                logger.info("Reproducer executed successfully.")
                # Check logs or output for crash evidence if needed
                return "Reproducer did not affect VM"
            except Exception as e:
                logger.error(f"Failed to retrieve long file from the VM: {e}")
                return None
            
        except subprocess.TimeoutExpired:
            logger.error("5 minutes passed, reproducer compilation timed out without crashing anything.")
            pull_scp_command = "scp -i {ssh_key} -P {ssh_port} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes root@localhost:/root/{config_type}.trace {icse_path}/get_results_output/trace_files"
            subprocess.run(
                    pull_scp_command.format(icse_path=icse_path, ssh_key=ssh_key, ssh_port=ssh_port, config_type=config_type),
                    check=True,
                    shell=True,
                    capture_output=True,
                    text=True
                )
            return "timeout"

    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to run reproducer in the VM: {e}")
        return None


def main():
    args = parse_args()

    if not args.config_file.exists():
        logger.error("Config file does not exist")
        return

    config = parse_config(args.config_file)

    debian_image = DebianImage(
        path_debian_image=config.debian_image_src / "bullseye.img",
        path_debian_image_key=config.debian_image_src / "bullseye.id_rsa",
    )

    kernel_image_paths = {}
    qemu_instances = []

    try:    
        kernel_image_paths["repaired"] = config.repaired_config_image
        kernel_image_paths["default"] = config.default_config_image
        logger.info(config.default_config_image)
        logger.info(config.repaired_config_image)
        for config_type, kernel_image_path in kernel_image_paths.items():
            logger.info(f"Starting QEMU for {config_type}...")

            qemu_instance = QemuInstance()
            boot_success = run_qemu(
                kernel_image_path=kernel_image_path,
                debian_image_path=debian_image.path_debian_image,
                qemu_instance=qemu_instance,
                timeout=300,
                commit_id=config.kernel_commit_id,
                config_type=config_type,
                reproducer_src=config.path_reproducer
            )

            if not boot_success:
                logger.error(f"Failed to start QEMU for {config_type}. Skipping...")
                continue

            logger.info(f"QEMU started successfully for {config_type}.")
            qemu_instances.append(qemu_instance)

        if qemu_instances:
            logger.info(
                f"QEMU instances started with PIDs: {[qemu_instance.pid for qemu_instance in qemu_instances]}"
            )
        else:
            logger.warning("No QEMU instances were started.")

    except Exception as e:
        logger.error(f"An error occurred: {e}")


    # finally:
    #     # Cleanup resources
    #     for path in kernel_image_paths.values():
    #         shutil.rmtree(path.parent, ignore_errors=True)
    #     logger.info("Temporary resources cleaned up.")

if __name__ == "__main__":
    main()


