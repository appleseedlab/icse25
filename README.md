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

You can follow [SUMMARY.md](SUMMARY.md) for a summary of the experimental setup and
set of actions that are performed during experiments.

## Prerequisites
Before running the experiments, please make sure that you have Python 3.9 or later
installed on your system. You can download Python from the [official website](https://www.python.org/downloads/).
Next, you need to run setup.sh script to install the required dependencies.
```bash
sudo ./setup.sh
```

## Kicking the Tires
To get a demo of the fuzzing experiments with and without configuration variety,
you can run the following command to conduct the experiments for 15 minutes:
```bash
#TODO
```

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
