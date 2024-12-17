# RQ1: (Bug discovery) How does configuration repair affect bug discovery?
This subdirectory contains the data and scripts used to answer the first research
question of the paper.

## Directory structure
|Subdirectory|Description|
|----|----|
|[figure2](figure2)|Subdirectory that contains scripts and data to get Figure 2.|
|[figure3](figure3)|Subdirectory that contains scripts and data to get Figure 3.|

## Figures and tables related to RQ1
### Fig. 2: Bugs found by syzkaller using krepaired configuration files compared to the original configuration files.
The directory `figure2` contains the data and scripts used to generate Figure 2
of the paper.
Figure 2a. depicts the venn diagram showing the total number of bugs found by
fuzzing with repaired and original configuration files.
Figure 2b. shows the number of previously-unknown bugs found by fuzzing with
repaired and original configuration files.

To generate the figures, run the following command:
#TODO: Replace with docker command
#TODO: Add a way to get pdf from docker and display it
```bash
python3 figure2/venn_diagram.py
```
> [!NOTE]
> This script uses hardcoded data, the total number of bugs found by fuzzing
with repaired and original configuration files manually obtained from `data_tables/Table_of_all_crashes.xlsx`.

The script will generate two pdf files: `all_bugs_venn_diagram.pdf` and `new_bugs_venn_diagram.pdf`.
They represent Figure 2a. and Figure 2b., respectively.

### Fig. 3: Comparison of the distribution of bugs found repaired and original configuration files.
The directory `figure3` contains the data and scripts used to generate Figure 3
of the paper.
Figure 3 shows the distribution of bugs found by fuzzing linux-next with repaired and
original configuration.
The most common type of bug found is the kernel warnings, followed by the
various kernel bugs and general protection faults.

To generate the figure, run the following command:
#TODO: Replace with docker command
#TODO: Add a way to get pdf from docker and display it
```bash
python3 figure3/categorize_bugs_bar_chart.py
```
> [!NOTE]
> This script uses list of the names of new bugs found by fuzzing with repaired
configuration files manually obtained from `data_tables/Table_of_all_crashes.xlsx` and
categorizes them.

This script will generate a pdf file `kernel_bug_categories_bar_chart.pdf` that
represents Figure 3.
