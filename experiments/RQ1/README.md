# RQ1: (Bug discovery) How does configuration repair affect bug discovery?
This subdirectory contains the data and scripts used to answer the first research
question of the paper.

## Directory structure

## Figures and tables related to RQ1
### Fig. 2: Bugs found by syzkaller using krepaired configuration files compared to the original configuration files.
The directory `figure2` contains the data and scripts used to generate Figure 2
of the paper.
Figure 2a. depicts the venn diagram showing the total number of bugs found by
fuzzing with repaired and original configuration files.
Figure 2b. shows the number of previously-unknown bugs found by fuzzing with
repaired and original configuration files.

To generate the figures, run the following command:
```bash
python3 venn_diagram.py
```

The script will generate two pdf files: `all_bugs_venn_diagram.pdf` and `new_bugs_venn_diagram.pdf`.
They represent Figure 2a. and Figure 2b., respectively.
