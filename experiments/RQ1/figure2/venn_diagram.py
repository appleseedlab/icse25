import matplotlib.pyplot as plt
from matplotlib_venn import venn2
import os

# NOTE: The numbers below are manually obtained from the data tables provided

# Total number of bugs found by each tool and their overlap
tool1_bugs = 267  # Tool 1 found 35 bugs
tool2_bugs = 228  # Tool 2 found 11 bugs that overlap with Tool 1 and 2 that don't
overlap_bugs = 31  # The number of bugs found by both tools

# The number of new bugs found by each tool
tool1_new_bugs = 24  # Tool 1 found 24 new bugs
tool2_new_bugs = 2  # Tool 2 found 2 new bugs
overlap_new_bugs = 11  # The number of bugs found by both tools

script_dir = os.path.dirname(os.path.realpath(__file__))

plt.figure(figsize=(8, 4))
# Creating the Venn diagram
venn = venn2(
    subsets=(tool1_bugs, tool2_bugs, overlap_bugs),
    set_labels=("Repaired", "Original"),
)

for text in venn.set_labels:
    if text:
        text.set_fontsize(18)

for text in venn.subset_labels:
    if text:
        text.set_fontsize(18)

venn.get_patch_by_id("10").set_color("#1f77b4")  # Tool 1 unique color
venn.get_patch_by_id("01").set_color("#ff7f0e")  # Tool 2 unique color
venn.get_patch_by_id("11").set_color("red")  # Overlap color

# Display the plot
# plt.title("Venn Diagram of Bugs Found by Tools")
pdf_filename = "all_bugs_venn_diagram.pdf"
print(f"Saved all bugs venn diagram to {script_dir}/{pdf_filename}")
plt.savefig(f"{script_dir}/{pdf_filename}")
plt.clf()

plt.figure(figsize=(8, 4))

venn_new = venn2(
    subsets=(tool1_new_bugs, tool2_new_bugs, overlap_new_bugs),
    set_labels=("Repaired", "Original"),
)


for text in venn_new.set_labels:
    if text:
        text.set_fontsize(18)

for text in venn_new.subset_labels:
    if text:
        text.set_fontsize(18)

venn_new.get_patch_by_id("10").set_color("#1f77b4")  # Tool 1 unique color
venn_new.get_patch_by_id("01").set_color("#ff7f0e")  # Tool 2 unique color
venn_new.get_patch_by_id("11").set_color("red")  # Overlap color

pdf_filename_new = f"{script_dir}/new_bugs_venn_diagram.pdf"
print(f"Saved new bugs venn diagram to {pdf_filename_new}")
plt.savefig(pdf_filename_new)
