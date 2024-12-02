# RQ3: (Configuration variety) How much configuration variety is introduced by configuration repair?
This subdirectory contains the data and scripts used to answer the third research
question of the paper.

## Directory structure
#TODO: Update the directory structure

## Figures and tables related to RQ2
### TABLE VI: Number of configurations options changed by krepair.
Table VI shows the distribution of the number of options changed as a five-point
summary, i.e., quartiles, the minimum, and the maximum, plus the 90th percentile
to show how the vast majority of cases behave.

The directory `table6` contains the data and scripts used to generate Table VI.

To reproduce the Table VI data, run the following command:
#TODO: Replace with docker command
#TODO: #FIXME This command provides a different output than the one in the paper.
```bash
python3 get_percentage_change.py
```
The script will output a file `table6/change_summary.pdf` containing the
percentage change in the number of configuration options for the original and
krepaired configuration files.
