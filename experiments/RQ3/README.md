# RQ3: (Configuration variety) How much configuration variety is introduced by configuration repair?
This subdirectory contains the data and scripts used to answer the third research
question of the paper.

## Directory structure
|Subdirectory|Description|
|----|----|
|[table6](table6)|Subdirectory that contains scripts and data to generate Table VI|

## Figures and tables related to RQ3
### TABLE VI: Number of configurations options changed by krepair. (Change Summary Study)
We evaluated how our approach changed the number of configuration options of
the original Syzkaller configuration files used in the experiments.

`change_summary.sh` script was used to evaluate the change in number of
configuration options of repaired syzkaller configuration files against the total
number of the configuration options available on the configuration system.

The CSV file that contains the names of the original and repaired syzkaller
configurations, and patch commits that are used to repair the original
configuration files can be found at `change_of_summaries_bug_finding_coverage.csv`.

Table VI shows the distribution of the number of options changed as a five-point
summary, i.e., quartiles, the minimum, and the maximum, plus the 90th percentile
to show how the vast majority of cases behave.

The directory `table6` contains the data and scripts used to generate Table VI.

To reproduce the Table VI data, use the following command:
```bash
bash table6/get_change_summary.sh
```
The script will output the percentile information of the change summary study.
