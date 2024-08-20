import matplotlib.pyplot as plt
import csv
from collections import Counter

# Read kernel bugs from CSV file into a list
kernel_bugs = []
with open("repaired_bugs2.csv", "r") as csvfile:
    csvreader = csv.reader(csvfile)
    for row in csvreader:
        if row:  # Check if row is not empty
            kernel_bugs.append(row[0])

# Function to categorize bugs
def categorize_bug(bug):
    if "deadlock" in bug:
        return "Deadlock"
    if "soft lockup" in bug:
        return "Deadlock"
    if "general protection fault" in bug:
        return "General Protection Fault"
    if "WARNING" in bug:
        return "Warning"
    if "kernel BUG" in bug:
        return "Unspecified Kernel Bug"
    if "kernel bug" in bug:
        return "Unspecified Kernel Bug"
    if "BUG: Bad page state" in bug:
        return "Unspecified Kernel Bug"
    if "BUG: sleeping function called from invalid context in console_lock" in bug:
        return "Unspecified Kernel Bug"
    if "BUG: unable to handle kernel paging request in wait_consider_task" in bug:
        return "Unspecified Kernel Bug"
    if "BUG: unable to handle kernel paging request in path_openat" in bug:
        return "Unspecified Kernel Bug"
    if "BUG: workqueue lockup" in bug:
        return "Unspecified Kernel Bug"
    if "UBSAN: array-index-out-of-bounds" in bug:
        return "Out of Bounds Access"
    if "UBSAN: shift-out-of-bounds" in bug:
        return "Integer Underflow/Overflow"
    if "KASAN: null-ptr-deref" in bug:
        return "NULL Pointer Dereference"
    if "BUG: unable to handle kernel NULL pointer dereference in rcu_core" in bug:
        return "NULL Pointer Dereference"
    if "KASAN: slab-use-after-free" in bug:
        return "Use-After-Free"
    if "KASAN: use-after-free" in bug:
        return "Use-After-Free"
    if "KASAN: stack-out-of-bounds" in bug:
        return "Out of Bounds Access"
    if "KASAN: slab-out-of-bounds" in bug:
        return "Out of Bounds Access"
    if "KASAN: user-memory-access Write in zram_submit_bio" in bug:
        return "Out of Bounds Access"
    if "INFO" in bug:
        return "Stalls"
    if "bug: unable to handle kernel NULL pointer dereference in rcu_core":
        return "NULL Pointer Dereference"
    return "Others"

# Categorize and count bugs found in repaired configs
categories_repaired = [categorize_bug(bug) for bug in kernel_bugs]
category_counts_repaired = Counter(categories_repaired)

# Total number of bugs for repaired configs
total_bugs_repaired = sum(category_counts_repaired.values())

# Default config statistics
category_counts_default = {
    "Warning": 30.5,
    "Unspecified Kernel Bug": 16.4,
    "Deadlock": 16.4,
    "Stalls": 12.6,
    "General Protection Fault": 8.2,
    "NULL Pointer Dereference": 6.3,
    "Use-After-Free": 4.5,
    "Out of Bounds Access": 4.1,
    "Integer Underflow/Overflow": 1.1
}

# Prepare data for bar chart
labels = list(set(category_counts_repaired.keys()) | set(category_counts_default.keys()))
sizes_repaired = [category_counts_repaired.get(label, 0) / total_bugs_repaired * 100 for label in labels]
sizes_default = [category_counts_default.get(label, 0) for label in labels]

# Replace "Out of Bounds Access" with "Out-of-Bounds" in labels
labels = ["Out-of-Bounds" if label == "Out of Bounds Access" else
          "BUG_ON()" if label == "Unspecified Kernel Bug" else label for label in labels]

# Sort the labels and sizes from smallest to largest and then reverse
sorted_data = sorted(zip(sizes_repaired, sizes_default, labels), reverse=True)
sizes_repaired, sizes_default, labels = zip(*sorted_data)
sizes_repaired, sizes_default, labels = sizes_repaired[::-1], sizes_default[::-1], labels[::-1]

# Plot horizontal bar chart with adjusted figure size
plt.figure(figsize=(12, 8))  # Adjusted figure size to make the chart wider

# Define the bar width and positions
bar_width = 0.35
r1 = range(len(labels))
r2 = [x + bar_width for x in r1]

# Create bars
bars1 = plt.barh(r1, sizes_repaired, height=bar_width, label='Repaired')
bars2 = plt.barh(r2, sizes_default, height=bar_width, label='Original')

# Increase label text size
plt.yticks([r + bar_width/2 for r in range(len(labels))], labels, fontsize=16)

# Remove x-axis tick marks and labels
plt.tick_params(
    axis="x",  # changes apply to the x-axis
    which="both",  # both major and minor ticks are affected
    bottom=False,  # ticks along the bottom edge are off
    top=False,  # ticks along the top edge are off
    labelbottom=False,  # labels along the bottom edge are off
)

# Turn off the top, right, and bottom axis lines, keep the left
ax = plt.gca()
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.spines["bottom"].set_visible(False)

# Function to add labels with consistent positioning relative to the longest bar
def add_labels(bars1, bars2, sizes1, sizes2, offset=5):
    for bar1, bar2, size1, size2 in zip(bars1, bars2, sizes1, sizes2):
        # Determine the maximum width of the two bars
        max_width = max(bar1.get_width(), bar2.get_width())

        # Calculate label positions
        label_y_pos1 = bar1.get_y() + bar1.get_height() / 2 - 0.05
        label_y_pos2 = bar2.get_y() + bar2.get_height() / 2 - 0.05

        # Place the labels at the same distance from the longest bar
        plt.text(
            max_width + offset - 5,
            label_y_pos1,
            f"{round(bar1.get_width(), 1)}%",
            va="center",
            ha="left",
            fontsize=16
        )
        plt.text(
            max_width + offset - 5,
            label_y_pos2,
            f"{round(bar2.get_width(), 1)}%",
            va="center",
            ha="left",
            fontsize=16
        )

# Add value labels to the bars
# Add value labels to the bars
add_labels(bars1, bars2, sizes_repaired, sizes_default, offset=7)

# Add legend
plt.legend(loc='lower right', fontsize=18)

# Save the plot as a PDF file
plt.savefig("kernel_bug_categories_comparison_bar_chart.pdf", format="pdf", bbox_inches="tight")

# Show the plot
plt.show()

