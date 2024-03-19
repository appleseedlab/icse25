import matplotlib.pyplot as plt
import csv
from collections import Counter

# Read kernel bugs from CSV file into a list
kernel_bugs = []
with open('guild_bugs2.csv', 'r') as csvfile:
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
        return "Kernel Bug"
    if "kernel bug" in bug:
        return "Kernel Bug"
    if "BUG: Bad page state" in bug:
        return "Kernel Bug"
    if "BUG: sleeping function called from invalid context in console_lock" in bug:
        return "Kernel Bug"
    if "BUG: unable to handle kernel paging request in wait_consider_task" in bug:
        return "Kernel Bug"
    if "BUG: unable to handle kernel paging request in path_openat" in bug:
        return "Kernel Bug"
    if "BUG: workqueue lockup" in bug:
        return "Kernel Bug"
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

# Prepare data for pie chart
labels = list(category_counts.keys())
sizes = list(category_counts.values())

# Plot pie chart
plt.figure(figsize=(10, 7))
patches, texts, autotexts = plt.pie(sizes, autopct='%1.1f%%')

for text in texts + autotexts:
    text.set_color('black')

plt.title('Kernel Bug Categories')
plt.legend(patches, labels, loc="best", bbox_to_anchor=(1, 0.5))
plt.savefig('kernel_bug_categories.pdf', format='pdf')
plt.show()

# to debug which bugs are left to be categorized
print("Bugs in 'Others' category:")
for bug, category in zip(kernel_bugs, categories):
    if category == "Others":
        print(bug)
