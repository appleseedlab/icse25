# Main Experiment: Fuzzing with and without Configuration Variety
This subdirectory contains the main fuzzing script to conduct fuzzing experiments
with and without configuration variety.

# Structure
|Subdirectory|Section|
|----|----|
|[fuzzing_experiments.sh](fuzzing_experiments.sh)|The main script that performs fuzzing w. and w.o. config variety and saves results.|
|[fuzzing_parameters.csv](fuzzing_parameters.csv)|CSV file that contains commit ids to repair config files with, original syzbot configuration files, repaired configuration files, and linux-next tags that fuzzed kernel images were built with.|
|[output](output/)|The folder where the results of fuzzing runs are saved.|

# Usage
The following command can be used to run the script that performs fuzzing without configuration variety using syzkaller:
```Bash
bash ./experiments/fuzzing/fuzzing_experiments.sh default ./experiments/fuzzing/fuzzing_parameters.csv ./linux-next/ ./syzkaller/ ./debian_image/ ./camera_ready/configuration_files/syzbot_configuration_files ./experiments/fuzzing/output/
```
Explanation of the parameters:
- default - type of the experiment. Can be either default or repaired.
- ./experiments/fuzzing/fuzzing_parameters.csv - a CSV file that contains the names of
the configuration files used during the fuzzing experiments and the commit IDs of
the Linux-next versions that were fuzzed.
- ./linux-next/ - the path to the linux-next repository that contains the tags of
the Linux kernel versions that were fuzzed.
- ./syzkaller/ - the path to the syzkaller repository.
- ./debian_image/ - the path to the directory that contains a debian image like
'bullseye.img' and its ssh key 'bullseye.id_rsa' that are used to boot the kernel
images built during the fuzzing experiments.
- ./camera_ready/configuration_files/syzbot_configuration_files - the path to the
directory that contains the syzkaller configuration files used during the fuzzing
- ./experiments/fuzzing/output/ - the path to the directory where the results of the
fuzzing experiments will be saved.
