# Content
## Artifacts

## data_tables folder
data_tables/ - this directory contains the data tables that were used to generate the figures and tables in the paper. They are summary of the results of the experiments conducted in the paper.
data_tables/Table_of_all_crashes.xlsx - this file contains the data about all alarms found during experiments with and without configuration variety. It has columns that represent the following:
- "Crash name" - the name of the crash
- "Full trace" - the call trace of the crash derived from the respective syzkaller bug report
- "Tool" - the tool that found the crash
- "Experiment" - the experiment where the crash was found
- "Fuzzed Linux Commit ID" - the commit ID of the Linux kernel that was being fuzzed
- "Patch Commit ID" - the patch used for generating the configuration variety
- "Blocks covered" - the number of basic blocks covered, only available for crashes found during "Coverage" experiment
- "Syscalls executed" - the number of system calls executed, only available for crashes found during "Coverage" experiment
- "Config option count" - the number of configuration options in the configuration file that was used to build the kernel for the experiment
- "Config file size(in bytes)" - the size of the configuration file that was used to build the kernel for the experiment
- "Binary size(in Mbs)" - the size of the kernel binary that was built for the experiment
- "Time taken to find" - the time taken by the fuzzer to find the crash
- "Reproducer available" - whether a reproducer was available for the crash
- "Reproducer type" - the type of reproducer available for the crash (Can be either a C reproducer or Syz reproducer, a syzkaller reproducer program)
- "Reproducer crashed on GUILD config" - whether the reproducer crashed on the kernel build with repaired configuration file
- "Reproducer crashed on Syzkaller config" - whether the reproducer crashed on the kernel build with the original syzkaller configuration file
- "Previously unreported" - whether the crash was previously unreported at the time of the experiment
- "Reported" - whether the crash was reported to the Linux kernel maintainers by us
#TODO

data_tables/GUILD-SYZKALLER Deduplicated Crash name+Trace(Bug Finding+Coverage).xlsx - this file contains the data about deduplicated alarms found during experiments with and without configuration variety.
data_tables/GUILD-SYZKALLER Only Crash+Call Trace(Bug Finding+Coverage).xlsx - this file contains the data about all alarms found during experiments with and without configuration variety. It contains the name of the crash with the call trace of the crash.
## repairer_script folder

- addr2line_inside_ifdef.py - This script compares two text files to identify lines that are different between them and determines whether these differing lines are located within conditional compilation blocks marked by #ifdef or #if in the source code. It reads the files, computes the differences, and then checks if each differing line is inside an #ifdef or #if block, printing the results.
- all_bugs.csv - ?
- all_bugs_results.csv - ?
- block_coverage_bar_chart.py - This script visualizes a comparison of code coverage, measured in the number of blocks, between two fuzzing with and without config variety, "KonfFuzz" and "Syzkaller" respectively, across multiple experimental runs. It plots sorted coverage data as side-by-side bars for each tool on a bar chart, labeling the y-axis with coverage values. The plot is saved to a PDF file named 'block_coverage_comparison_chart.pdf'.
- bug_comparison_results.csv - ?
- bugs_unique_and_common.py - This script is used for comparing unique and common crash names found by fuzzing with and without configuration variety. It needs crash names belonging to fuzzing with configuration variety at column 1 and crash names belonging to fuzzing without configuration variety at column 2.
- build_kernel.sh - This script is used to build the Linux kernel with a given configuration file and commit hash. Built kernel images are needed to run them in QEMU to test whether reproducers of crashes crash on kernels built with and without configuration variety.
- categorize_bugs_bar_chart.py - This script is used for categorizing all crashes found by fuzzing with configuration variability based on their types. It reads the names of the crashes from the provided csv file and categorizes them into different types, then visualizes the results as a bar chart and saves it to a PDF file named 'categorized_bugs_bar_chart.pdf'.
- collect_reproducers.sh - This script reads the names and paths to the reproducers of crashes from guild_reproducers.csv file and checks the type of the reproducer. It puts C reproducers to /home/sanan/research/guil_dreproducers/c_reproducers and syzkaller reproducers to /home/sanan/research/guil_dreproducers/syz_reproducers.
- find_reproducers.sh - this scripts is used for finding reproducers and their types (C or syz) in guild_bugs folders, the folder that stores folders of bug found during fuzzing with configuration variety. It generates reproducers.csv file and stores them there.
- find_unique_crash.py - This script is used to find unique alarm name + call trace pairs from results of fuzzing with and without configuration variety. It reads the results from the provided csv file and finds unique alarm name + call trace pairs, then saves them to a new csv file.
- fuzzing_syzkaller_default.sh - This script is used to perform fuzzing without configuration variety using syzkaller. It uses configuration file arbitrarily selected from syzbot dashboard and a linux-next tag to checkout to build the kernel and starts fuzzing with syzkaller while saving the outputs.
- get_call_trace.py - This Python script automates the process of extracting call traces from syzkaller bug reports, categorizing them based on uniqueness, and compiling bug statistics.
- get_source_lines_of_code_default.sh - This script is used to get the number of source lines of code of the Linux kernel binary built with configuration file without configuration variety.
- get_source_lines_of_code_repaired.sh - This script is used to get the number of source lines of code of the Linux kernel binary built with configuration file with configuration variety.
- guild_bugs.csv - a csv file that contains the names of all crashes found by fuzzing with configuration variety.
- guild_bugs2.csv - a csv file that contains the names of all previously unreported crashes found by fuzzing with configuration variety.
- guild_reproducers.csv - a csv file that contains the names of all crashes found by fuzzing with configuration variety that has reproducers. It stores the names of the crashes, reproducer types, and paths to the reproducers.
- ifdef_find_bug_relevance.py - tis script checks whether configuration options related to files that contain definitions of functions found in the call trace of a bug's syzkaller report or configuration options related to conditional blocks that may cover the call of those functions exist in configuration files with and without configuration variety.
- input.csv - ?
- kernel_size_and_modules.py - This script automates the process of compiling the Linux kernel with different configurations, measuring the size of the resulting kernel images and modules, and logging the results to a CSV file. It iterates over rows in an input CSV file, each specifying a commit ID and paths to syzkaller and repaired configuration files. For each row, the script checks out the specified commit, cleans the kernel directory, applies both configurations (with and without config variety, syzkaller and repaired) one after the other, compiles the kernel, and calculates the size of the compiled kernel image (bzImage) and modules. The sizes are then logged in the CSV file along with the commit ID and configuration file names, facilitating the comparison of kernel sizes across different configurations and commits.
- output.csv - ?
- output_traces.csv - ?
- source_lines.csv - this csv is used by get_source_lines_of_code_default.sh and get_source_lines_of_code_repaired.sh to get configuration file names, commit IDs, and linux-next tags.
- source_lines.sh - This script is designed to process C source files (*.c) in a specified Linux kernel directory, attempting to find corresponding preprocessed files (*.i). For each .c file with a matching .i file, it extracts lines from the .i file that originated from the .c file, saving these lines to a new text file. The script is used by get_source_lines_of_code_default.sh and get_source_lines_of_code_repaired.sh to extract source lines of code from the Linux kernel binary.
- start_guild_10day_experiment.sh - this script is used to perform 10 day fuzzing with configuration variety using KonfFuzz. It uses configuration file arbitrarily selected from syzbot dashboard, a randomly selected linux-next patch id to repair the syzbot configuration file with, and a linux-next tag to checkout to build the kernel and starts fuzzing with KonfFuzz while saving the outputs.
- start_syzkaller_10day_experiment.sh - this script is used to perform 10 day fuzzing without configuration variety using syzkaller. It uses configuration file arbitrarily selected from syzbot dashboard and a linux-next tag to checkout to build the kernel and starts fuzzing with syzkaller while saving the outputs.
- syscall_exec_bar_chart.py - this script is used to generate bar chart to compare throughput of fuzzing with and without configuration variety. It uses throughput data manually obtained from data_tables/Table_of_all_crashes.xlsx.
- time_taken_scatterplot.py - This script is used to visualize time taken to find bugs found by fuzzing with and without configuration variety.
- venn_diagram.py - This script is used to generate Venn diagrams to compare unique and common bugs found by fuzzing with and without configuration variety. It uses data manually obtained from data_tables/Table_of_all_crashes.xlsx.

## krepair_syzkaller_evaluation folder

- run_many_syzkaller_evaluations.sh - This Bash script orchestrates the evaluation of Syzkaller configurations against a set of Linux kernel commit IDs, which can either be provided through a file or fetched from a server. It sets up the environment for each kernel commit, invoking another script to run the actual evaluation for Syzkaller fuzzing configurations, and organizes the output into directories named after the commit IDs.
- run_evaluate_syzkaller_config.sh - This script generates a syzkaller configuration file with Syzkaller's syz-kconf utility and runs evaluate_syzkaller_config.sh to check how many lines of the commit it covers.
- evaluate_syzkaller_config.sh - This script is used to evaluate the coverage of a syzkaller configuration file. It uses koverage tool from kmax tool suite to see whether there are lines from the patch commit that are excluded in syzkaller configuration file, and if yes, the script uses klocalizer tool from kmax to "repair" the syzkaller config to include those lines as well.
- calculate_confidence_intervals.py - This script is used to calculate the confidence intervals of the coverage of syzkaller and repaired configuration files. It uses the coverage data obtained from evaluate_syzkaller_config.sh.








# Figures

## Figure (Distribution of kernel bug types found by KonfFuzz.)
In this figure, you can see the types of bugs found by KonfFuzz. The most common type of bug found is the kernel warnings, followed by the various kernel bugs and general protection faults.
To get the figure, you can run the following command:
```Python
python3 categorize_bugs_bar_chart.py
```

This script uses list of the names of new bugs found by KonfFuzz obtained from data_tables/Table_of_all_crashes.xlsx and categorizes them.

## Figure (12-hour total bugs found by KonfFuzz and Syzkaller and 12-hour new bugs found by KonfFuzz and Syzkaller.)
In the first figure, you can see the total number of bugs found by KonfFuzz and Syzkaller in 12 hours. 
In the second figure, you can see the new bugs found by KonfFuzz and Syzkaller in 12 hours.

The following command can be used to get the both figures:
```Python
python3 venn_diagram.py
```

This script uses the quantity of total and new bugs found both by KonfFuzz and Syzkaller obtained from data_tables/Table_of_all_crashes.xlsx and provides two Venn diagrams that describe the intersection of these two sets in terms of total and new bugs.

## Table (12-hour previously-unreported kernel bugs found by KonfFuzz, and their current post-reporting status)
The table depicts the previously unreported kernel bugs found by KonfFuzz and their current post-reporting status. The table is obtained from data_tables/Table_of_all_crashes.xlsx.

## Figure (12-hour test cases executed by KonfFuzz and Syzkaller.)
The figure shows the number of test cases executed by KonfFuzz and Syzkaller over 10 runs that lasted 12 hours each.
To get the figure, you can run the following command:
```Python
python3 syscall_exec_bar_chart.py
```
The script uses the quantity of test cases executed by KonfFuzz and Syzkaller obtained from data_tables/Table_of_all_crashes.xlsx.

## Figure (12-hour basic block coverage of KonfFuzz and Syzkaller.)
This figure shows the basic block coverage of KonfFuzz and Syzkaller over 10 runs that lasted 12 hours each.
To get the figure, you can run the following command:
```Python
python3 block_coverage_bar_chart.py
```

## Table (10-day fuzzing bug-finding and performance of KONFFUZZ versus Syzkaller. We report code coverage as measured in basic blocks, and throughput as the total system call sequences executed)
#TODO

## Table (Bugs confirmed to be found with configuration-dependent paths.)
#TODO
