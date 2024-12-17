# A Little Goes a Long Way: Tuning Configuration Selection for Continuous Kernel Fuzzing

<p><a href="https://paulgazzillo.com/papers/icse25.pdf"><img alt="thumbnail" align="right" width="200" src="images/thumbnail.png"></a></p>

The Linux kernel is actively-developed and widely used.
It supports billions of devices of all classes, from high-performance computing
to the Internet-of-Things, in part because of its sophisticated configuration
system, which automatically tailors the source code according to thousands of
user-provided configuration options.
Fuzzing has been highly successful at finding kernel bugs, being among the top
bug reporters. Since the kernel receives 100s of patches per day, fuzzers run
continuously, stopping regularly to rebuild the kernel with the latest
changes before restarting fuzzing.
But kernel fuzzers currently use predefined configuration settings that, as we
show, exclude the majority of new patches from the kernel binary,
nullifying the benefits of continuous fuzzing.
Unfortunately, state-of-the-art configuration testing techniques are generally
ill-suited to the needs of continuous fuzzing, excluding necessary options or
requiring too many configuration files to be tractable.
We distill down the needs of continuous testing into six properties with the
most impact, systematically analyze the space of configuration selection strategies,
and provide actionable recommendations.
Through our analysis, we discover that continuous fuzzers can improve configuration
variety without sacrificing performance.
We empirically evaluate our discovery by modifying the configuration selection
strategy for syzkaller, the most popular Linux kernel fuzzer, which subsequently
found more than twice as many new bugs (35 vs. 13) than with the original
configuration file and 12x more (24 vs. 2) when considering only unique bugs—with
one security vulnerability being assigned a CVE.

For more information, please refer to [our paper](https://paulgazzillo.com/papers/icse25.pdf)
from ICSE25.

[experiments](experiments/) directory contains instructions, data, and scripts
to reproduce the experiments in the paper.

## Guide to the Artifacts
*Note:* Please make sure to follow the steps below after entering the repo:
1. To be able to run the scripts, you need to have [kmax](https://github.com/paulgazz/kmax) and [syzkaller](https://github.com/google/syzkaller) installed.
Please refer to the installation instructions of these tools to install them.
2. Please also make sure to use Python3 3.9 or above to able to run the scripts in this repository.
3. Make sure to enable kmax virtual environment before running the scripts.
4. You will need the contents of "repaired_reproducers.7z" and "repaired_bugs.7z" files when running some of the scripts.
Since they are files large in size, you have to pull them first with 'git lfs pull' command once you clone the repository.
After pulling the files, you can extract them with the commands below:
```
7z x repaired_reproducers.7z
7z x repaired_bugs.7z
```
4. You will need a linux-next repo that contains the linux-next daily tags to be able to run the scripts in this repository.
You can find our linux-next repo that contains the tags we used in the experiments [here](https://drive.google.com/file/d/1H_aNBlJZ9qBLF0gvOflBE3-rou0EEbmT/view?usp=sharing)
Extract the repo with the following command:
```
7z x linux-next.7z
```

This guide provides information on how we used the artifacts during the experiments and post-processing of the results.
First, we initiate the 12-hour experiment with configuration variety using repairer.sh script.
The script will take a random start and end date and an arbitrary syzkaller configuration file taken from the syzbot dashboard.
It will collect all the commit IDs belonging to the interval between start and end dates.
Next up, it will check the commit IDs one by one against the configuration file with koverage to see if the configuration file includes lines in the patch commit.
If not, klocalizer will be used to repair the configuration file to include those lines.
Then, a kernel image will be built with the repaired configuration file and syzkaller will start fuzzing the image for 12 hours.

The same 12-hour experiment will be conducted without configuration variety using original syzkaller configurations using repairer_script/fuzzing_experiments.sh script.
Next, we will use the scripts to post-process the results of the experiments.
In the beginning, we analyze crash folders of each run of fuzzing with and without configuration variety to check whether previously unreported bugs are present and need to be reported to the Linux kernel mailing list.
To check whether a bug is previously unreported we manually analyze the bug's alarm name and call trace and compare it with the existing bug reports with the same description in the Linux kernel mailing list.

If the bug is previously unreported, we report it to the Linux kernel mailing list. To report the bug, we use the following steps:
1. We first determine at what source file the bug occurred from the syzkaller bug report.
2. Next, we provide the file name to the script called ./scripts/get_mainter.pl to obtain the email addresses of the maintainers of the file.
3. Then, we generate a bug report and include the head commit ID of the Linux-next version we fuzzed, link to the kernel configuration file used to build the kernel, a reproducer file (if exists) to reproduce the crash, and syzkaller bug report of the crash.

find_reproducers.sh can be used to find reproducers of the crashes found during the aforementioned experiment, fuzzing with and without configuration variety. Reproducers are necessary to be included in the bug reports as they help the maintainers analyze the crash. They are also useful to check whether the crash is reproducible on the kernel built with the original syzkaller configuration files.
To be able to check that, we use collect_reproducers.sh to sort reproducers based on their type (C or syz programs) and then manually upload them to kernel emulated with QEMU to see if they crash.

We also use build_kernel.sh, script to build kernel images based on a provided set of configuration files and commit tags to checkout.
We also analyze whether the crash is the result of configuration option changes our tool made while repairing the syzkaller configuration file. For instance, we used ifdef_find_bug_relevance.py to check whether configuration options related to files that contain definitions of functions found in the call trace of a bug's syzkaller report or configuration options related to conditional blocks that may cover the call of those functions exist in configuration files with and without configuration variety.
If there are configuration options that exist in the repaired configuration and not in the original syzkaller configuration and if that option caused a source file that contained the definition of a function found in the call trace of the bug to be included, or it caused an #ifdef conditional block to that covered the call of the function to be included, we consider that our changes led to the crash.

In addition, we instrumented reproducer files generated by syzkaller to have KCOV visibility to get program counters executed by the reproducer. We later converted those program counters to source code lines and checked if those lines existed inside of an #ifdef conditional block that turned true with our modification to a configuration option, with the help of addr2line_inside_ifdef.py.

We also analyze and deduplicate the alarms found during the experiments with and without configuration variety using the scripts find_unique_crash.py and bugs_unique_and_common.py. With the help of these scripts, we also check the bugs found that are unique to each experiment and the bugs that are common to both experiments. These results can be found in data_tables/Repaired-SYZKALLER Deduplicated Crash name+Trace(Bug Finding+Coverage).xlsx and data_tables/Repaired-SYZKALLER Only Crash+Call Trace(Bug Finding+Coverage).xlsx.
Overall, more information about the experiments and the results can be found in data_tables/Table_of_all_crashes.xlsx.

### Change Summary Study

We evaluated how our approach changed the number of configuration options of the original Syzkaller configuration files used in the experiments.
krepair_syzkaller_evaluation/change_summary_2.sh script was used to evaluate the change in number of configuration options of repaired Syzkaller configuration files against the total number of the configuration options available on the configuration system.
The number of total configuration options was obtained from the configuration system of the Linux kernel using find_total_config_option_count.sh script. The CSV file that contains the names of the original and repaired Syzkaller configuration, and patch commits that are used to repair the original configuration files can be found at change_of_summaries_bug_finding_coverage.csv The CSV file that contains the names of the original and repaired Syzkaller configuration, and patch commits that are used to repair the original configuration files is change_of_summaries_bug_finding_coverage.csv.
We calculated the change of summary percentile information and represented them in a table. You can view Table(Number of configurations options changed by krepair) to see the results of the change summary study.
## Artifacts

- build_allnoconfig.sh - This script is used to build the Linux kernel with an allnoconfig configuration file.
- build_allyesconfig.sh - This script is used to build the Linux kernel with an allyesconfig configuration file.
- calculate_confidence_interval.py - This script is used to calculate the confidence intervals of the coverage of Syzkaller and repaired configuration files and provides a bar chart to visualize the results.
- change_of_summaries_bug_finding_coverage.csv - this CSV file contains the names of the original and repaired Syzkaller configuration, and patch commits that are used to repair the original configuration files.
- defconfig_config_patchcoverage.txt - this file contains the patch coverage of defconfig configuration files.
- defconfig_krepair_patchcoverage.txt - this file contains the patch coverage of repaired defconfig configuration files.
- find_total_config_option_count.sh - This script is used to get the number of configuration options available in the configuration system of the Linux kernel.
- get_percentage_change.py - this script is used to measure the change in the number of configuration options of repaired Syzkaller configuration files against the total number of configuration options available on the configuration system.
- kafl_config_patchcoverage.txt - this file contains the patch coverage of kAFL configuration files.
- kaf_krepair_patchcoverage.txt - this file contains the patch coverage of repaired kAFL configuration files.
- syzkaller_config_patchcoverage.txt - this file contains the patch coverage of Syzkaller configuration files.
- krepair_patchcoverage.txt - this file contains the patch coverage of repaired Syzkaller configuration files.
- links_to_syzkaller_configuration_used.txt - this file contains the links to the syzkaller configuration files used during fuzzing experiments.
- test_100_randconfigs.py - this script is used to generate 100 configuration files with randconfig utility, build kernel images with them, and try to boot the kernel images with QEMU.
- kafl_krepair_experiment_j8.csv - this file contains the results of the replication study for kAFL and repaired kAFL configuration files.
- syzkaller_krepair_experiment_j8.csv - this file contains the results of the replication study for Syzkaller and repaired Syzkaller configuration files.
- defconfig_krepair_experiment_j8.csv - this file contains the results of the replication study for defconfig and repaired defconfig configuration files.
## data_tables folder
data_tables/ - This directory contains the data tables that were used to generate the figures and tables in the paper. They are a summary of the results of the experiments conducted in the paper.
data_tables/Table_of_all_crashes.xlsx - this file contains the data about all alarms found during experiments with and without configuration variety. It has columns that represent the following:
- "Crash name" - the name of the crash
- "Full trace" - the call trace of the crash derived from the respective syzkaller bug report
- "Tool" - the tool that found the crash
- "Experiment" - the experiment where the crash was found
- "Fuzzed Linux Commit ID" - the commit ID of the Linux kernel that was being fuzzed
- "Patch Commit ID" - the patch used for generating the configuration variety
- "Blocks covered" - the number of basic blocks covered, only available for crashes found during the "Coverage" experiment
- "Syscalls executed" - the number of system calls executed, only available for crashes found during the "Coverage" experiment
- "Config option count" - the number of configuration options in the configuration file that was used to build the kernel for the experiment
- "Config file size(in bytes)" - the size of the configuration file that was used to build the kernel for the experiment
- "Binary size(in Mbs)" - the size of the kernel binary that was built for the experiment
- "Time taken to find" - the time taken by the fuzzer to find the crash
- "Reproducer available" - whether a reproducer was available for the crash
- "Reproducer type" - the type of reproducer available for the crash (Can be either a C reproducer or Syz reproducer, a Syzkaller reproducer program)
- "Reproducer crashed on repaired config" - whether the reproducer crashed on the kernel build with the repaired configuration file
- "Reproducer crashed on Syzkaller config" - whether the reproducer crashed on the kernel build with the original Syzkaller configuration file
- "Previously unreported" - whether the crash was previously unreported at the time of the experiment
- "Reported" - whether the crash was reported to the Linux kernel maintainers by us
- "LKML Discussion" - whether the crash was discussed on the Linux kernel mailing list
- "Developers Responded" - whether the Linux kernel developers responded to the bug report
- "Developers Confirmed" - whether the Linux kernel developers confirmed the bug
- "Developers Patched" - whether the Linux kernel developers patched the bug
- "CVE Issued" - whether a CVE was issued for the bug

data_tables/Repaired-SYZKALLER Deduplicated Crash name+Trace(Bug Finding+Coverage).xlsx - this file contains the data about deduplicated alarms found during experiments with and without configuration variety.
data_tables/Repaired-SYZKALLER Only Crash+Call Trace(Bug Finding+Coverage).xlsx - this file contains the data about all alarms found during experiments with and without configuration variety. It contains the name of the crash with the call trace of the crash.
## repairer_script folder

- addr2line_inside_ifdef.py - This script compares two text files to identify lines that are different between them and determines whether these differing lines are located within conditional compilation blocks marked by #ifdef or #if in the source code. It reads the files, computes the differences, and then checks if each differing line is inside a #ifdef or #if block, printing the results.
- block_coverage_bar_chart.py - This script visualizes a comparison of code coverage, measured in the number of blocks, between two fuzzing with and without config variety, "Our Approach" and "Syzkaller" respectively, across multiple experimental runs. It plots sorted coverage data as side-by-side bars for each tool on a bar chart, labeling the y-axis with coverage values. The plot is saved to a PDF file named 'block_coverage_comparison_chart.pdf'.
- bugs_unique_and_common.py - This script is used for comparing unique and common crash names found by fuzzing with and without configuration variety. It needs crash names belonging to fuzzing with configuration variety in column 1 and crash names belonging to fuzzing without configuration variety in column 2.
- build_kernel.sh - This script is used to build the Linux kernel with a given configuration file and commit hash. Built kernel images are needed to run them in QEMU to test whether reproducers of crashes crash on kernels built with and without configuration variety.
- categorize_bugs_bar_chart.py - This script is used for categorizing all crashes found by fuzzing with configuration variability based on their types. It reads the names of the crashes from the provided CSV file and categorizes them into different types, then visualizes the results as a bar chart and saves it to a PDF file named 'categorized_bugs_bar_chart.pdf'.
- collect_reproducers.sh - This script reads the names and paths to the reproducers of crashes from the repaired_reproducers.csv file and checks the type of the reproducer.
Example command to run the script:
```bash
./collect_reproducers.sh guild_reproducers/ repairer_script/repaired_reproducers.csv guild_bugs/
```
- find_reproducers.sh - this script is used for finding reproducers and their types (C or syz) in repaired_bugs folders, the folder that stores folders of bugs found during fuzzing with configuration variety. It generates reproducers.csv files and stores them there.
- find_unique_crash.py - This script is used to find unique alarm names + call trace pairs from the results of fuzzing with and without configuration variety. It reads the results from the provided CSV file and finds unique alarm names + call trace pairs, then saves them to a new CSV file.
- fuzzing_experiments.sh - This script is used to perform fuzzing without configuration variety using Syzkaller. It uses a configuration file arbitrarily selected from the Syzbot dashboard and a Linux-next tag to check out to build the kernel and starts fuzzing with Syzkaller while saving the outputs.
- get_call_trace.py - This Python script automates the process of extracting call traces from Syzkaller bug reports, categorizing them based on uniqueness, and compiling bug statistics.
- get_source_lines_of_code_default.sh - This script is used to get the number of source lines of code of the Linux kernel binary built with configuration file without configuration variety.
- get_source_lines_of_code_repaired.sh - This script is used to get the number of source lines of code of the Linux kernel binary built with a configuration file with configuration variety.
- repaired_bugs.csv - a CSV file that contains the names of all crashes found by fuzzing with configuration variety.
- repaired_bugs2.csv - a CSV file that contains the names of all previously unreported crashes found by fuzzing with configuration variety.
- repaired_reproducers.csv - a CSV file that contains the names of all crashes found by fuzzing with configuration variety that has reproducers. It stores the names of the crashes, reproducer types, and paths to the reproducers.
- ifdef_find_bug_relevance.py - this script checks whether configuration options related to files that contain definitions of functions found in the call trace of a bug's Syzkaller report or configuration options related to conditional blocks that may cover the call of those functions exist in configuration files with and without configuration variety.
- kernel_size_and_modules.py - This script automates the process of compiling the Linux kernel with different configurations, measuring the size of the resulting kernel images and modules, and logging the results to a CSV file. It iterates over rows in an input CSV file, each specifying a commit ID and paths to Syzkaller and repaired configuration files. For each row, the script checks out the specified commit, cleans the kernel directory, applies both configurations (with and without configuration variety, Syzkaller and repaired) one after the other, compiles the kernel, and calculates the size of the compiled kernel image (bzImage) and modules. The sizes are then logged in the CSV file along with the commit ID and configuration file names, facilitating the comparison of kernel sizes across different configurations and commits.
- source_lines.csv - this csv is used by get_source_lines_of_code_default.sh and get_source_lines_of_code_repaired.sh to get configuration file names, commit IDs, and Linux-next tags.
- source_lines.sh - This script is designed to process C source files (*.c) in a specified Linux kernel directory, attempting to find corresponding preprocessed files (*.i). For each .c file with a matching .i file, it extracts lines from the .i file that originated from the .c file, saving these lines to a new text file. The script is used by get_source_lines_of_code_default.sh and get_source_lines_of_code_repaired.sh to extract source lines of code from the Linux kernel binary.
- syscall_exec_bar_chart.py - this script is used to generate a bar chart to compare the throughput of fuzzing with and without configuration variety. It uses throughput data manually obtained from data_tables/Table_of_all_crashes.xlsx.
- time_taken_scatterplot.py - This script is used to visualize the time taken to find bugs found by fuzzing with and without configuration variety.
- venn_diagram.py - This script is used to generate Venn diagrams to compare unique and common bugs found by fuzzing with and without configuration variety. It uses data manually obtained from data_tables/Table_of_all_crashes.xlsx.

## krepair_syzkaller_evaluation folder

- run_many_syzkaller_evaluations.sh - This Bash script orchestrates the evaluation of Syzkaller configurations against a set of Linux kernel commit IDs, which can either be provided through a file or fetched from a server. It sets up the environment for each kernel commit, invoking another script to run the actual evaluation for Syzkaller fuzzing configurations and organizes the output into directories named after the commit IDs.
- run_evaluate_syzkaller_config.sh - This script generates a Syzkaller configuration file with Syzkaller's syz-kconf utility and runs evaluate_syzkaller_config.sh to check how many lines of the commit it covers.
- evaluate_syzkaller_config.sh - This script is used to evaluate the coverage of a Syzkaller configuration file. It uses the koverage tool from the kmax tool suite to see whether there are lines from the patch commit that are excluded in the Syzkaller configuration file, and if yes, the script uses the klocalizer tool from kmax to "repair" the Syzkaller config to include those lines as well.
- calculate_confidence_intervals.py - This script is used to calculate the confidence intervals of the coverage of Syzkaller and repaired configuration files. It uses the coverage data obtained from evaluate_syzkaller_config.sh.
- change_summary_2.sh - this script is used to find out how many configuration options were added to the original Syzkaller configuration files by our approach.
- data_summary.sh - This script is used to summarize the results of the replication study.
- data_summaries.sh - this script is used to run many data_summary.sh scripts for many datasets.
- measure_change.py - this script is used to measure the change in the number of configuration options of repaired Syzkaller configuration files against the total number of configuration options available on the configuration system. It is used inside the change_summary_2.sh script
- coverable_patches - this file contains the list of patches that are used in the replication study.
- total_coverage.py - this script is used to merge the output of koverage into a single coverage report. It is used inside evaluate_syzkaller_config.sh script.

## krepair_kafl_evaluation_folder
This folder contains the same scripts as krepair_syzkaller_evaluation folder but for kAFL configuration files.

# Figures

## Change Summary Study Script

The following command can be used to get the results of change summary study:
```Python
bash krepair_syzkaller_evaluation/change_summary_2.sh change_study.csv
```
change_study.csv is a csv file that contains the names of original and repaired Syzkaller configuration, and patch commits that are used to repair the original configuration files.
