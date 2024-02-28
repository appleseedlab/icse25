import argparse
import subprocess
import logging
import time
import shutil
import git
import os
import csv


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
        "-o",
        "--output_dir",
        type=str,
        required=True,
        help="Output directory",
    )

    args = parser.parse_args()
    return args


def generate_randconfigs(kernel_src):
    command = "KCONFIG_PROBABILTIY=10 make randconfig"

    try:
        result = subprocess.run(
            command, shell=True, cwd=kernel_src, check=True, capture_output=True
        )
        logging.info(result.stdout)

    except Exception as e:
        logging.error(e)


def main():
    args = parse_args()
    generate_randconfigs(args.kernel_src)


if __name__ == "__main__":
    main()
