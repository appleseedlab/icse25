# RQ2: (Performance impacts) How does configuration repair affect performance?
This subdirectory contains the data and scripts used to answer the second research
question of the paper.

## Directory structure
#TODO: Update the directory structure

## Figures and tables related to RQ2
### TABLE IV: Five-point summaries of kernel configuration time in seconds.
Table IV summarizes the distributions of configuration times for both the
original and krepaired configuration files. To configure the kernel with an
existing configuration file, the user runs make olddefconfig, which imports an
existing configuration file, checking it for consistency.
This process typically takes only seconds, as shown in the five-point summary
for the original configuration.
For the krepaired configuration files, we first run krepair on the
configuration file before importing it, which can take several minutes.
The directory `table4` contains the data and scripts used to generate Table IV.

#### Original Configuration Generation Times
To reproduce the 'Original Configurations' column data,
run the following command:
```bash
docker exec -it artifacts-container sh -c "python3 icse25/camera_ready/five_point_summary.py --file icse25/experiments/RQ2/table4/original/default_config_times.csv";
```
> [!NOTE]
> The script used to measure the time taken to generate Linux kernel configuration
files was executed during our initial experimentation, and the resulting timings
were recorded in a CSV file called 'table4/original/default_config_times.csv'.
These recorded timings were subsequently used to populate the table of results in this paper.
It is worth noting that rerunning the script may produce slightly different
timing results due to factors such as variations in system load, background
processes, or other environmental conditions during execution.
To ensure consistency and reproducibility in the reported results, we rely on
the originally recorded data, which accurately reflects the conditions under which
the measurements were initially conducted.
> However, if readers still wish to run the script to generate the timing results
themselves, they can use the following command:
```bash
docker exec -it artifacts-container sh -c "bash icse25/experiments/RQ2/table4/original/get_config_times.sh"
```
> This will create a file named `table4/original/config_times.csv` containing the
newly generated timing results.

#### Repaired Configuration Generation Times
To reproduce the 'Repaired Configurations' column data,
run the following command:
#TODO: Replace with docker command
```bash
docker exec -it artifacts-container sh -c "python3 icse25/camera_ready/five_point_summary.py --file icse25/experiments/RQ2/table4/repaired/repaired_config_times.csv";
```
> [!NOTE]
> The script used to measure the time taken to generate repaired Linux kernel configuration
files was executed during our initial experimentation, and the resulting timings
were recorded in a CSV file called 'table4/repaired/repaired_config_times.csv'.
These recorded timings were subsequently used to populate the table of results in this paper.
It is worth noting that rerunning the script may produce slightly different
timing results due to factors such as variations in system load, background
processes, or other environmental conditions during execution.
To ensure consistency and reproducibility in the reported results, we rely on
the originally recorded data, which accurately reflects the conditions under which
the measurements were initially conducted.
> However, if readers still wish to run the script to generate the timing results
themselves, they can use the following command:
```bash
docker exec -it artifacts-container sh -c "python3 -m pip install loguru; python3 icse25/experiments/RQ2/table4/repaired/get_config_times_repaired.py"
```
> This will create a file named `table4/repaired/config_times.csv` containing the
newly generated timing results.

### TABLE V: Five-point summaries of kernel build times in seconds.
The directory `table5` contains the data and scripts used to generate Table V.
of the paper.
Table V summarizes the distributions of build times for the original and krepaired
configuration files.
Once configured, we build each kernel, parallelized with make -j, measuring its
time.
Given the small configuration files and high core-count of the experiment
machine, build times were less than 10 minutes in all cases.

To get the data for the 'Original Configurations' column of Table V,
run the following command:
#TODO: Replace with docker command
```bash
bash table5/original/get_build_times.sh
```
The script will output a file `table5/original/build_times.csv` containing the
build times for the original configuration files.
> [!NOTE]
> To get the 'Original Configurations' column data of Table V,
you can view `table5/original/default_build_times.csv` file.


To get the data for the 'Repaired Configurations' column of Table V,
run the following command:
#TODO: Replace with docker command
```bash
bash table5/repaired/get_build_times_repaired.sh
```
The script will output a file `table5/repaired/build_times.csv` containing the
build times for the repaired configuration files.
> [!NOTE]
> To get the 'Repaired Configurations' column data of Table V,
you can view `table5/repaired/repaired_build_times.csv` file.

### Fig. 4: Comparing syzkaller performance before and after using krepair.
The directory `figure4` contains the data and scripts used to generate Fig. 4.

#### Fig 4a. syzkaller throughput with the original and krepaired configuration.

To get Fig. 4a, run the following command:
```bash
docker exec -it artifacts-container sh -c "python3 icse25/experiments/RQ2/figure4/syscall_exec_bar_chart.py"; docker cp artifacts-container:/home/apprunner/icse25/experiments/RQ2/figure4/syscalls_comparison_chart.pdf ./syscalls_comparison_chart.pdf; open ./syscalls_comparison_chart.pdf
```
The script will output a file `figure4/syscalls_comparison_chart.pdf` which is
a bar chart comparing the throughput of the original and krepaired configuration
files.
> [!NOTE]
> Throughput data across fuzzing runs for the original and krepaired is hardcoded
in the script. Throughtput data is obtained from syzkaller logs. You can view
the throughput data in `data_tables/Table_of_all_crashes.xlsx` file.

#### Fig 4b. syzkaller coverage with both the original and krepaired configuration.

To get Fig. 4b, run the following command:
```bash
docker exec -it artifacts-container sh -c "python3 icse25/experiments/RQ2/figure4/block_coverage_bar_chart.py"; docker cp artifacts-container:/home/apprunner/icse25/experiments/RQ2/figure4/block_coverage_comparison_chart.pdf ./block_coverage_comparison_chart.pdf; open ./block_coverage_comparison_chart.pdf
```
The script will output a file `figure4/block_coverage_comparison_chart.pdf` which is
a bar chart comparing the block coverage of the original and krepaired configuration
files.
> [!NOTE]
> Coverage data across fuzzing runs for the original and krepaired is hardcoded
in the script. Coverage data is obtained from syzkaller logs. You can view
the coverage data in `data_tables/Table_of_all_crashes.xlsx` file.
