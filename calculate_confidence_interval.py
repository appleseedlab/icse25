import numpy as np
import scipy.stats
import argparse
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.lines as mlines


def parse_args():
    parser = argparse.ArgumentParser(description="Calculate confidence interval")
    parser.add_argument(
        "--syzkaller_file", type=str, help="Path to the syzkaller file with the data"
    )
    parser.add_argument(
        "--krepair_file", type=str, help="Path to the krepair file with the data"
    )
    parser.add_argument(
        "--kafl_file", type=str, help="Path to the kafl file with the data"
    )
    parser.add_argument(
        "--kafl_krepair_file",
        type=str,
        help="Path to the kafl krepair file with the data",
    )
    parser.add_argument(
        "--defconfig_file", type=str, help="Path to the defconfig file with the data"
    )
    parser.add_argument(
        "--defconfig_krepair_file",
        type=str,
        help="Path to the defconfig repair file with the data",
    )
    parser.add_argument(
        "--confidence", type=float, default=0.95, help="Confidence level"
    )
    return parser.parse_args()


def generate_list_from_file(file_path):
    with open(file_path, "r") as file:
        lines = file.readlines()
        lines = [line.strip() for line in lines]
        lines = [float(line) for line in lines if line and line != "n/a"]
    return lines


def calculate_std(data):
    return np.std(data)


def mean_confidence_interval(data, confidence=0.95):
    a = 1.0 * np.array(data)
    n = len(a)
    m, se = np.mean(a), scipy.stats.sem(a)
    h = se * scipy.stats.t.ppf((1 + confidence) / 2.0, n - 1)
    return m, m - h, m + h


def plot_confidence_interval(means, ci_diffs, labels):
    fig, ax = plt.subplots()
    bars = ax.bar(
        labels,
        means,
        yerr=np.transpose(ci_diffs),
        capsize=10,
    )
    ax.set_ylabel("Mean Value")
    ax.set_title("Mean and Confidence Interval of Datasets")
    plt.xticks(
        rotation=0, fontsize=9
    )  # Optional: improves readability of x-axis labels
    plt.show()


def plot_box_and_whisker(syzkaller_data, krepair_data):
    fig, ax = plt.subplots()
    # Customizing the box plot appearance
    boxprops = dict(linestyle="-", linewidth=3, color="k")
    whiskerprops = dict(linestyle="-", linewidth=2, color="k")
    medianprops = dict(linestyle="-", linewidth=2.5, color="firebrick")
    meanlineprops = dict(linestyle="--", linewidth=2.5, color="purple")

    # Plotting the box plot
    bp = ax.boxplot(
        [syzkaller_data, krepair_data],
        patch_artist=True,
        showmeans=True,
        meanline=True,
        boxprops=boxprops,
        whiskerprops=whiskerprops,
        medianprops=medianprops,
        meanprops=meanlineprops,
    )

    ax.set_xticklabels(["Syzkaller", "Krepair"])
    ax.set_ylabel("Values")
    ax.set_title("Box and Whisker Plot of Two Datasets")

    # Coloring the boxes
    colors = ["lightblue", "lightgreen"]
    for patch, color in zip(bp["boxes"], colors):
        patch.set_facecolor(color)

    # Creating custom legends
    mean_legend = mlines.Line2D(
        [], [], color="purple", linestyle="--", linewidth=2.5, label="Mean"
    )
    median_legend = mlines.Line2D(
        [], [], color="firebrick", linestyle="-", linewidth=2.5, label="Median"
    )
    box_legend = mpatches.Patch(color="lightblue", label="Interquartile Range (IQR)")
    whisker_legend = mlines.Line2D(
        [], [], color="black", linestyle="-", linewidth=2, label="Whiskers (Range)"
    )

    plt.legend(
        handles=[mean_legend, median_legend, box_legend, whisker_legend], loc="best"
    )

    plt.show()


def main():
    args = parse_args()
    syzkaller_data = generate_list_from_file(args.syzkaller_file)
    krepair_data = generate_list_from_file(args.krepair_file)

    kafl_data = generate_list_from_file(args.kafl_file)
    kafl_krepair_data = generate_list_from_file(args.kafl_krepair_file)

    datasets = [syzkaller_data, krepair_data, kafl_data, kafl_krepair_data]
    labels = ["Syzkaller", "Repaired Syzkaller Configs", "KAFL", "Repaired KAFL Config"]
    means = []
    ci_diffs = []

    for data in datasets:
        mean, ci_lower, ci_upper = mean_confidence_interval(
            data, confidence=args.confidence
        )
        means.append(mean)
        ci_diffs.append((mean - ci_lower, ci_upper - mean))

    # Plotting the confidence intervals for all datasets
    plot_confidence_interval(means, ci_diffs, labels)


if __name__ == "__main__":
    main()
