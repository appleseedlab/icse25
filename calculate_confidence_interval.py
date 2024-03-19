import numpy as np
import scipy.stats
import argparse
import matplotlib.pyplot as plt


def parse_args():
    parser = argparse.ArgumentParser(description="Calculate confidence interval")
    parser.add_argument(
        "--syzkaller_file", type=str, help="Path to the syzkaller file with the data"
    )
    parser.add_argument(
        "--krepair_file", type=str, help="Path to the krepair file with the data"
    )
    parser.add_argument(
        "--confidence", type=float, default=0.95, help="Confidence level"
    )
    return parser.parse_args()


def generate_list_from_file(file_path):
    with open(file_path, "r") as file:
        lines = file.readlines()
        lines = [line.strip() for line in lines]
        lines = [float(line) for line in lines if line]
    return lines


def calculate_std(data):
    return np.std(data)


def mean_confidence_interval(data, confidence=0.95):
    a = 1.0 * np.array(data)
    n = len(a)
    m, se = np.mean(a), scipy.stats.sem(a)
    h = se * scipy.stats.t.ppf((1 + confidence) / 2.0, n - 1)
    return m, m - h, m + h


def plot_confidence_interval(means, ci_diffs):
    fig, ax = plt.subplots()
    bars = ax.bar(
        ["Dataset Syzkaller Config", "Dataset Krepair"],
        means,
        yerr=np.transpose(ci_diffs),
        capsize=10,
    )
    ax.set_ylabel("Mean Value")
    ax.set_title("Mean and Confidence Interval of Two Datasets")
    plt.show()


def plot_box_and_whisker(syzkaller_data, krepair_data):
    fig, ax = plt.subplots()
    ax.boxplot([syzkaller_data, krepair_data])
    ax.set_xticklabels(["Syzkaller", "Krepair"])
    ax.set_ylabel("Mean Value")
    ax.set_title("Box and Whisker Plot of Two Datasets")
    plt.show()


