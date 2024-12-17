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
Table VI shows the distribution of the number of options changed as a five-point
summary, i.e., quartiles, the minimum, and the maximum, plus the 90th percentile
to show how the vast majority of cases behave.

The directory `table6` contains the data and scripts used to generate Table VI.

To reproduce the Table VI data, use the following command:
```bash
bash table6/get_change_summary.sh
```
The script will output a file `table6/change_summary.pdf` containing the
percentage change in the number of configuration options for the original and
krepaired configuration files.
