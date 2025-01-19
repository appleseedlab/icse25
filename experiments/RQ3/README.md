# RQ3: (Configuration variety) How much configuration variety is introduced by configuration repair?
This subdirectory contains the data and scripts used to answer the third research
question of the paper.

## Directory structure
|Subdirectory|Description|
|----|----|
|[table6](table6)|Subdirectory that contains scripts and data to generate Table VI|
|[krepair_syzkaller_evaluation](krepair_syzkaller_evaluation)|Subdirectory that contains results of change summary experiment with krepaired and default syzkaller configs|
|[krepair_kafl_evaluation](krepair_kafl_evaluation)|Subdirectory that contains results of change summary experiment with krepaired and default KAFL configs|

## Figures and tables related to RQ3
### TABLE VI: Number of configurations options changed by krepair. (Change Summary Study)
We evaluated how our approach changed the number of configuration options of the original Syzkaller configuration files used in the experiments.
krepair_syzkaller_evaluation/change_summary_2.sh script was used to evaluate the change in number of configuration options of repaired Syzkaller configuration files against the total number of the configuration options available on the configuration system.
The number of total configuration options was obtained from the configuration system of the Linux kernel using find_total_config_option_count.sh script. The CSV file that contains the names of the original and repaired Syzkaller configuration, and patch commits that are used to repair the original configuration files can be found at change_of_summaries_bug_finding_coverage.csv The CSV file that contains the names of the original and repaired Syzkaller configuration, and patch commits that are used to repair the original configuration files is change_of_summaries_bug_finding_coverage.csv.
We calculated the change of summary percentile information and represented them in a table. You can view Table(Number of configurations options changed by krepair) to see the results of the change summary study.
Table VI shows the distribution of the number of options changed as a five-point
summary, i.e., quartiles, the minimum, and the maximum, plus the 90th percentile
to show how the vast majority of cases behave.

The directory `table6` contains the data and scripts used to generate Table VI.

To reproduce the Table VI data, use the following command:
```bash
docker exec -it artifacts-container sh -c "bash icse25/experiments/RQ3/table6/get_change_summary.sh";
```
The script will output the percentile information of the change summary study.
