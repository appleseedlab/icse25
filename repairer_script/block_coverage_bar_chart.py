import matplotlib.pyplot as plt
import numpy as np
import matplotlib.ticker as ticker

# Data for each experiment
repaired_coverage = [
    202517,
    163366,
    195761,
    186634,
    168517,
    167623,
    186059,
    179930,
    171702,
    172877,
]
syzkaller_coverage = [
    173919,
    171336,
    193565,
    101231,
    154619,
    170338,
    182554,
    185740,
    168181,
    144643,
]

indexed_repaired_coverage = list(enumerate(repaired_coverage))
indexed_repaired_coverage.sort(key=lambda x: x[1], reverse=True)

sorted_repaired_coverage = [x[1] for x in indexed_repaired_coverage]
sorted_syzkaller_coverage = [
    syzkaller_coverage[x[0]] for x in indexed_repaired_coverage
]

# repaired_coverage_sorted = sorted(repaired_coverage, reverse=True)
# syzkaller_coverage_sorted = sorted(syzkaller_coverage, reverse=True)

# Setting up the figure and axis
plt.figure(figsize=(10, 6))

# Number of runs
n_runs = len(sorted_repaired_coverage)

# Creating an index for each run to plot the bars side by side
ind = np.arange(n_runs)
width = 0.35

# Plotting the bars
plt.bar(ind, sorted_repaired_coverage, width, label="Repaired", color="#1f77b4")
plt.bar(
    ind + width, sorted_syzkaller_coverage, width, label="Original", color="#ff7f0e"
)

# Adding labels and title
plt.xlabel("Fuzzer Runs", fontsize=18)
plt.ylabel("Coverage (# of Blocks)", fontsize=18)
# plt.title('Block Coverage Comparison between repaired and Syzkaller Experiments')

plt.gca().yaxis.set_major_formatter(
    ticker.FuncFormatter(lambda x, p: format(int(x), ","))
)
plt.tick_params(axis="y", labelsize=16)
# Adding x-tick labels
plt.xticks([])

# Adding a legend
plt.legend(fontsize=16)

# Show the plot
plt.tight_layout()
plt.savefig("block_coverage_comparison_chart.pdf")
plt.close()
