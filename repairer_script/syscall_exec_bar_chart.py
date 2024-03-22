import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import FuncFormatter
from matplotlib.pyplot import figure

# Data for Konffuz and Syzkaller
konffuz_data = [
    11276034,
    3998137,
    7721839,
    3784246,
    8528421,
    6155654,
    8421053,
    5853355,
    5860776,
    5865318,
]
syzkaller_data = [
    4961822,
    4028549,
    7460204,
    505494,
    6143775,
    7279661,
    7713645,
    6644319,
    5747121,
    1917158,
]

paired_data = list(zip(konffuz_data, syzkaller_data))
sorted_paired_data = sorted(paired_data, key=lambda x: x[0], reverse=True)
sorted_konffuz_data, sorted_syzkaller_data = zip(*sorted_paired_data)

# Number of runs
num_runs = 10


def comma_formatter(x, pos):
    """Formats numbers with comma as a thousand separator."""
    return f"{int(x):,}"


# Creating a bar chart
fig, ax = plt.subplots(figsize=(12, 8))

index = np.arange(num_runs)
bar_width = 0.35

rects1 = ax.bar(
    index, sorted_konffuz_data, bar_width, label="Repaired", color="#1f77b4"
)
rects2 = ax.bar(
    index + bar_width,
    sorted_syzkaller_data,
    bar_width,
    label="Original",
    color="#ff7f0e",
)

ax.set_xlabel("Fuzzer Runs", fontsize=18)
ax.set_ylabel("Throughput (# of system call sequences executed)", fontsize=18)
# ax.set_title('Number of Syscalls per Run for Konffuz and Syzkaller')
ax.set_xticks([])
# ax.set_yticklabels(plt.yticks()[1], fontsize=8)
ax.tick_params(
    axis="both", which="major", labelsize=14
)  # Set tick param fontsize to 14
# plt.tight_layout()
# ax.set_xticklabels(range(1, num_runs + 1))
ax.yaxis.set_major_formatter(
    FuncFormatter(comma_formatter)
)  # Setting comma formatter for y-axis
ax.legend(fontsize=16)

# Save the plot to a PDF file
pdf_filename = "syscalls_comparison_chart.pdf"
plt.savefig(pdf_filename)
