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
    fig, ax = plt.subplots(figsize=(6.4, 3.3))

    # Convert means to percentages
    means_percent = [x * 100 for x in means]
    ci_diffs_percent = [(ci_diff[0] * 100, ci_diff[1] * 100) for ci_diff in ci_diffs]

    plt.rcParams.update({"font.size": 10})

    # Number of groups and number of bars in each group
    n_groups = 3  # For example, Syzkaller, KAFL, Defconfig
    n_bars_in_group = 2  # Original and Repaired

    # Bar width, spacing, and initial position
    bar_width = 0.1
    space_between_bars = 0.00001

    # Calculate the positions for the groups
    n_groups = len(labels) // 2
    n_bars_in_group = 2
    group_width = n_bars_in_group * (bar_width + space_between_bars)
    initial_left = np.arange(n_groups) * (group_width + bar_width)

    # Colors for the bars
    colors = ["#1f77b4", "#ff7f0e"]

    # Plotting each bar
    for i in range(n_bars_in_group):
        bar_positions = [
            left + (bar_width + space_between_bars) * i for left in initial_left
        ]
        means_subset = means_percent[i::n_bars_in_group]
        ci_diffs_subset = np.transpose(ci_diffs_percent[i::n_bars_in_group])

        error_bar_capsize = 5
        additional_offset = 2

        bars = ax.bar(
            bar_positions,
            means_subset,
            0.1,
            yerr=ci_diffs_subset,
            label=labels[i::n_bars_in_group][0],
            color=colors[i],
        )

        # Label bars with the updated mean values in percentage
        for bar, mean_value in zip(bars, means_subset):
            # Adjust the y coordinate for the text to avoid the error bar
            text_y_position = (
                bar.get_height() + error_bar_capsize / 2 + additional_offset
            )
            ax.text(
                bar.get_x() + bar.get_width() / 2,
                text_y_position,
                f"{mean_value:.1f}%",
                ha="center",
                va="bottom",
                fontsize=10,
            )

    ax.set_ylabel("Patch Coverage (%)")

    # Setting the x-ticks and labels
    group_labels = [
        "Syzkaller",
        "KAFL",
        "Defconfig",
    ]  # This assumes a certain ordering in your datasets and labels
    ax.set_xticks(initial_left + group_width / 2 - bar_width / 2)
    ax.set_xticklabels(group_labels)

    max_mean_plus_ci = max(
        [mean + ci[1] for mean, ci in zip(means_percent, ci_diffs_percent)]
    )
    label_padding = 10
    ax.set_ylim(0, max_mean_plus_ci + label_padding)

    ax.legend(loc="upper left", bbox_to_anchor=(0.76, 1.22), fontsize=10)

    plt.xticks(rotation=45)

    plt.savefig("patchcoverage_comparison.pdf", format="pdf", bbox_inches="tight")
    # plt.show()


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

    defconfig_data = generate_list_from_file(args.defconfig_file)
    defconfig_krepair_data = generate_list_from_file(args.defconfig_krepair_file)

    datasets = [
        syzkaller_data,
        krepair_data,
        kafl_data,
        kafl_krepair_data,
        defconfig_data,
        defconfig_krepair_data,
    ]
    labels = [
        "Original",
        "Repaired",
        "KAFL",
        "Repaired KAFL Config",
        "Defconfig",
        "Repaired Defconfig Configs",
    ]
    means = []
    ci_diffs = []

    for data, label in zip(datasets, labels):
        mean, ci_lower, ci_upper = mean_confidence_interval(
            data, confidence=args.confidence
        )

        print(
            f"Dataset: {label}, Mean: {mean}, CI Lower: {ci_lower}, CI Upper: {ci_upper}"
        )
        means.append(mean)
        ci_diffs.append((mean - ci_lower, ci_upper - mean))

    # Plotting the confidence intervals for all datasets
    plot_confidence_interval(means, ci_diffs, labels)


if __name__ == "__main__":
    main()
