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
        f"{output_dir}/randconfig_experiment_results.csv", "w", newline=" "
    ) as csv_file:
        csvwriter = csv.writer(csv_file)

    csvwriter.writerow([seed, probability, config_path])




def main():
    args = parse_args()
    generate_randconfigs(args.kernel_src)


if __name__ == "__main__":
    main()
