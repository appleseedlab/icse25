# Content
#TODO

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
