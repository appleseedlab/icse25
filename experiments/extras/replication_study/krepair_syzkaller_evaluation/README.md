<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Structure](#structure)
- [Evaluation](#evaluation)
  - [Sampling patches](#sampling-patches)
    - [Filtering out non-source code patches](#filtering-out-non-source-code-patches)
  - [Running experiments](#running-experiments)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Structure

- run_many_syzkaller_evaluations.sh - This Bash script orchestrates the evaluation of Syzkaller configurations against a set of Linux kernel commit IDs, which can either be provided through a file or fetched from a server. It sets up the environment for each kernel commit, invoking another script to run the actual evaluation for Syzkaller fuzzing configurations and organizes the output into directories named after the commit IDs.
- run_evaluate_syzkaller_config.sh - This script generates a Syzkaller configuration file with Syzkaller's syz-kconf utility and runs evaluate_syzkaller_config.sh to check how many lines of the commit it covers.
- evaluate_syzkaller_config.sh - This script is used to evaluate the coverage of a Syzkaller configuration file. It uses the koverage tool from the kmax tool suite to see whether there are lines from the patch commit that are excluded in the Syzkaller configuration file, and if yes, the script uses the klocalizer tool from kmax to "repair" the Syzkaller config to include those lines as well.
- calculate_confidence_intervals.py - This script is used to calculate the confidence intervals of the coverage of Syzkaller and repaired configuration files. It uses the coverage data obtained from evaluate_syzkaller_config.sh.
- change_summary_2.sh - this script is used to find out how many configuration options were added to the original Syzkaller configuration files by our approach.
- data_summary.sh - This script is used to summarize the results of the replication study.
- data_summaries.sh - this script is used to run many data_summary.sh scripts for many datasets.
- measure_change.py - this script is used to measure the change in the number of configuration options of repaired Syzkaller configuration files against the total number of configuration options available on the configuration system. It is used inside the change_summary_2.sh script
- sample - this file contains the list of randomly selected patches that are used in the replication study.
- coverable_patches - this file contains the list of patches that have coverable lines of code
that are used in the replication study.
- total_coverage.py - this script is used to merge the output of koverage into a
single coverage report. It is used inside evaluate_syzkaller_config.sh script.

# Evaluation

## Sampling patches

- Clone the stable linux repo: git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
- Get commits from the last year
- Filter in only those that touch code (.c/.h)
  - git log --until=2022-09-18 --since=2021-09-19 --no-merges
  - ... | grep ^commit | wc -l was 71,896
  - https://www.calculator.net/sample-size-calculator.html?type=1&cl=99&ci=5&pp=50&ps=71896&x=84&y=21
    - sample size 660 for 99% confidence in a 5% margin of error for a population of 71,896
- Take a random sample
  - head -n660 /dev/urandom > randfile  # randfile already generated and saved
  - git log --until=2022-09-18 --since=2021-09-19 --no-merges --pretty=format:%H | shuf --random-source=randfile | head -n660 > sample


### Filtering out non-source code patches

    # run the experiment on syzkaller configs
    bash run_many_syzkaller_evaluations.sh ./sample |& tee experiment.out

    # get those configs that have coverable lines in them
    ls ./outdir/*/syzkaller_config/results/koverage_outfile | while read i; do egrep "(INCLUDED|EXCLUDED)" $i >/dev/null 2>&1; if [[ $? -eq 0 ]]; then echo $i; fi; done | awk -F'/' '{print $2}' > coverable_patches_rep
    cat coverable_patches_rep | wc -l
    507


- Run koverage on each commit
- Check whether any lines exist included in the coverage report
- Results in 507 patches

## Running experiments

To get the line coverage data of syzkaller configurations, run the following
script first:
```bash
bash run_many_syzkaller_evaluations.sh
```
This script will run the evaluation for all the patches in the coverable_patches file
and measure and compare the line coverage of the default syzkaller configurations
and the repaired syzkaller configurations.
The output will be stored in the `outdir/` directory in the same directory as the script
by default.

Next, to get the csv files with the summary of the data, run the following script:
```bash
bash data_summary.sh > syzkaller_krepair_experiment.csv
```
This script will generate a csv file with the summary of the data collected from the
evaluation of the default and repaired syzkaller configurations.
