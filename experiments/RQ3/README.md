# RQ3: (Configuration variety) How much configuration variety is introduced by configuration repair?
This subdirectory contains the data and scripts used to answer the third research
question of the paper.

## Directory structure
#TODO: Update the directory structure

## Figures and tables related to RQ3
### TABLE VI: Number of configurations options changed by krepair. (Change Summary Study)
Table VI shows the distribution of the number of options changed as a five-point
summary, i.e., quartiles, the minimum, and the maximum, plus the 90th percentile
to show how the vast majority of cases behave.

The directory `table6` contains the data and scripts used to generate Table VI.

To reproduce the Table VI data, first we need to obtain change summary study results.
The following command can be used to get the results of change summary study:
```bash
bash krepair_syzkaller_evaluation/change_summary_2.sh change_study.csv > change_of_summaries_bug_finding_coverage.csv
```

change_study.csv is a csv file that contains the names of original and repaired
syzkaller configuration, and patch commits that are used to repair the original
configuration files.

#TODO: Replace with docker command
#TODO: #FIXME This command provides a different output than the one in the paper.
Then, we can utilize this command to get the actual percentage changes obtained
from change_of_summaries_bug_finding_coverage.csv:
```bash
python3 get_percentage_change.py
```
The script will output a file `table6/change_summary.pdf` containing the
percentage change in the number of configuration options for the original and
krepaired configuration files.
