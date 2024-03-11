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
    parser.add_argument(
        "-gr",
        "--gitref",
        type=str,
        default="v6.7",
        required=False,
        help="Git reference to checkout to",
    )
    parser.add_argument(
        "-t",
        "--timeout",
        type=str,
        default="3",
        required=False,
        help="Timeout duration",
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
        f"{output_dir}/randconfig_experiment_results.csv", "a", newline=""
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


def git_checkout_commit(kernel_src: str, commit_hash: str):
    repo = git.Repo(kernel_src)
    repo.git.checkout(commit_hash)
    return repo.head.commit.hexsha


def compile_kernel(kernel_src_list, generated_config_files, output_dir, commit_hash):
    config_not_compiled = []
    for kernel_src, config_file in zip(kernel_src_list, generated_config_files):
        git_clean(kernel_src)
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


def prepare_syzkaller_configs(
    kernel_src: str, syzkaller_config_path: str, output_syzkaller_config_list: list
) -> tuple[list, list]:
    kernel_src_list = []
    kernel_src_list.append(kernel_src)

    syzkaller_config_list = []

    syzkaller_config_dirname = os.path.dirname(syzkaller_config_path)

    for i in range(2, 10):
        kernel_src_list.append(f"{kernel_src}-{i}")
        logging.debug(f"Appended {kernel_src_list[-1]} to the list")

    syzkaller_port = 56742
    for kernel_folder in kernel_src_list:
        syzkaller_output_path = (
            syzkaller_config_dirname + f"/{os.path.basename(kernel_folder)}.cfg"
        )
        syzkaller_config_list.append(syzkaller_output_path)

        with open(syzkaller_config_path, "r") as file:
            data = json.load(file)

        data["http"] = f"127.0.0.1:{syzkaller_port}"
        data["kernel_obj"] = kernel_folder
        data["vm"]["kernel"] = f"{kernel_folder}/arch/x86/boot/bzImage"
        data["vm"]["count"] = 2
        data["vm"]["mem"] = 2048
        data["vm"]["cpu"] = 2
        data["workdir"] = f"{kernel_folder}_{time.time()}_workdir"
        logging.debug(f"Workdir: {data['workdir']}")
        logging.debug(f"Kernel object: {data['kernel_obj']}")
        logging.debug(f"VM object: {data['vm']['kernel']}")

        with open(syzkaller_output_path, "w") as outfile:
            json.dump(data, outfile, indent=4)

        syzkaller_port += 1

    return kernel_src_list, syzkaller_config_list


def run_syzkaller_in_parallel(
    syzkaller_config_list: list, timeout_duration: str = "1"
) -> list:
    logging.debug("Running syzkaller in parallel")
    tmux_sessions_list = []

    for syzkaller_config in syzkaller_config_list:
        syzkaller_path = "/home/sanan/Documents/syzkaller"
        command = f"cd {syzkaller_path}; ./bin/syz-manager -config={syzkaller_config}"

        tmux_session_name = syzkaller_config.replace(".", "_")

        logging.debug(f"Session name: {tmux_session_name}")

        result = subprocess.Popen(
            ["tmux", "new-session", "-d", "-s", tmux_session_name],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        stdout, stderr = result.communicate()

        logging.debug(
            f"tmux create command result: {stdout.decode('utf-8')}, {stderr.decode('utf-8')}"
        )

        tmux_sessions_list.append(tmux_session_name)

        try:
            result = subprocess.Popen(
                [
                    "tmux",
                    "send-keys",
                    "-t",
                    tmux_session_name,
                    command,
                    "C-m",
                ],
                cwd=syzkaller_path,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            stdout, stderr = result.communicate()

            logging.debug(
                f"send initial command result: {stdout.decode('utf-8')}, {stderr.decode('utf-8')}"
            )
        except subprocess.CalledProcessError as e:
            logging.error(f"tmux send-keys failed with exception: {e}")
            sys.exit(1)

        # try:
        #     result = subprocess.run(
        #         ["tmux", "send-keys", "-t", tmux_session_name, "C-c"],
        #         text=True,
        #         check=True,
        #     )
        #     logging.debug(f"result: {result.stdout}, {result.stderr}")
        # except Exception as e:
        #     logging.error(f"tmux errored out with exception: {e}")

    return tmux_sessions_list
    # try:
    #     result = subprocess.Popen(
    #         command,
    #         cwd=syzkaller_path,
    #         shell=True,
    #     )
    #
    #     logging.debug(f"Running syzkaller with pid: {result.pid}")
    #     if result.returncode != 0:
    #         logging.error(result.stderr)
    # except subprocess.CalledProcessError as e:
    #     logging.error(e)


def timeout_to_download_html(
    timeout_duration: int, saved_coverage_file_path: str, config_path_list: list
):
    timeout_duration_hours = int(timeout_duration) * 60
    buffer_time = 60

    wait_duration = timeout_duration_hours - buffer_time
    time.sleep(wait_duration)

    logging.debug(f"Timeout duration: {timeout_duration}")
    for config_path in config_path_list:
        with open(config_path, "r") as file:
            data = json.load(file)

        coverage_port = data["http"].split(":")[-1]
        download_html(saved_coverage_file_path, config_path, coverage_port)


def terminate_syzkaller_sessions(tmux_sessions_list: list):
    for session in tmux_sessions_list:
        try:
            result = subprocess.run(
                ["tmux", "send-keys", "-t", session, "C-c"],
                text=True,
                check=True,
            )
            logging.debug(f"result: {result.stdout}, {result.stderr}")
        except Exception as e:
            logging.error(f"tmux errored out with exception: {e}")


def download_html(saved_coverage_file_path, coverage_file_name, coverage_port):
    url = f"http://127.0.0.1:{coverage_port}/rawcover"
    response = requests.get(url)

    saved_coverage_file_path += "/" + os.path.basename(coverage_file_name)

    logging.debug(f"new saved_coverage_file_path: {saved_coverage_file_path}")

    with open(saved_coverage_file_path, "wb") as file:
        file.write(response.content)


def main():
    args = parse_args()

    loglevel = args.verbose
    numeric_level = getattr(logging, loglevel.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError("Invalid log level: %s" % loglevel)
    logging.basicConfig(level=loglevel)

    generated_config_files = generate_randconfigs(args.kernel_src, args.output_dir)
    # compile_kernel(args.kernel_src, generated_config_files, args.output_dir)

    kernel_src_list, syzkaller_config_list = prepare_syzkaller_configs(
        args.kernel_src, args.syzkaller_config, args.output_config_list
    )

    failed_to_compile = compile_kernel(
        kernel_src_list, generated_config_files, args.output_dir
    )

    if len(failed_to_compile) != 0:
        logging.warning(f"Some configs failed to be compiled: {failed_to_compile}")

    # for i in range(len(kernel_src_list)):
    #     logging.debug(f"Kernel src: {kernel_src_list[i]}")

    run_syzkaller_in_parallel(syzkaller_config_list)


if __name__ == "__main__":
    main()
