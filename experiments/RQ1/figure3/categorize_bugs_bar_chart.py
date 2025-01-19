import matplotlib.pyplot as plt
import csv
from collections import Counter
import os

# Read kernel bugs from CSV file into a list
kernel_bugs = []
script_dir = os.path.dirname(os.path.realpath(__file__))
with open(f"{script_dir}/repaired_bugs2.csv", "r") as csvfile:
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


# Categorize and count
categories = [categorize_bug(bug) for bug in kernel_bugs]
category_counts = Counter(categories)

# Calculate total number of bugs
total_bugs = sum(category_counts.values())

# Prepare data for bar chart
labels = list(category_counts.keys())
sizes = [value / total_bugs * 100 for value in category_counts.values()]

# Sort the labels and sizes from smallest to largest and then reverse
sorted_categories = sorted(zip(sizes, labels), reverse=True)
sizes, labels = zip(*sorted_categories)
sizes, labels = sizes[::-1], labels[::-1]  # Reverse the lists

# Plot horizontal bar chart with adjusted figure size
plt.figure(figsize=(6, 7))  # Adjusted figure size to make the chart narrower
bars = plt.barh(labels, sizes, height=0.5)  # Make bars narrower with height parameter

# Increase label text size
plt.yticks(fontsize=12)  # Increase font size for y-axis labels

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

# Optional: Adding value labels next to the bars with increased space
for bar in bars:
    width = bar.get_width()
    plt.text(
        width + 1,
        bar.get_y() + bar.get_height() / 2,
        f"{round(width, 1)}%",
        va="center",
    )  # Add a small buffer of +1 after width

# Save the plot as a PDF file
print(f"Saving the plot at {script_dir}/kernel_bug_categories_bar_chart.pdf")
plt.savefig(f"{script_dir}/kernel_bug_categories_bar_chart.pdf", format="pdf", bbox_inches="tight")

# Show the plot
plt.show()
