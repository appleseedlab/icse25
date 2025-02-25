# Extras
This subdirectory contains data and scripts that are not directly used to get
the results for research questions.
But they are used within the project to get some statistical and analytical insights.

# Structure
| Visual              | Section   |
|---------------------|-----------|
| [Replication Study](replication_study)| III       |
| [Bootability Study](bootability_study) | IV.C |
| [Table VIII](table8)| VI.A      |

## Replication Study
We conducted a replication study to evaluate the patch coverage of the
configuration files used by syzkaller and kAFL.

We used more than 600 commits from linux-next to measure the patch coverage of
each configuration file generated by **syz-kconf** utility of syzkaller and
default configuration file of kAFL obtained from
[here](https://github.com/IntelLabs/kafl.targets/blob/master/linux-kernel/config.vanilla.virtio).

Results of this study are depicted in **Figure 1**.

### Figure 1: Average patch coverage of syzkaller, kAFL, and defconfig.
**Figure 1** illustrates the results of a replication study involving
configuration files used by the kernel fuzzers Syzkaller and kAFL, along with
their corresponding repaired configuration files.

To conduct this study, we utilized the **syz-kconf** utility to generate
Syzkaller configuration files for each commit ID.
We then applied the **koverage** tool from the kmax suite to identify any patch
commit lines excluded from the original Syzkaller configuration files.
If exclusions were detected, the **klocalizer** tool from kmax was used to
"repair" the configuration files, ensuring the inclusion of the missing lines.
The same procedure was performed for kAFL, using the configuration file provided
in the kAFL tutorial.

We quantified the increase in patch coverage achieved by the repaired
configuration files compared to the original Syzkaller and kAFL configurations
using the **calculate_confidence_intervals.py** script.
Additionally, we generated a bar chart to visualize the results of the
replication experiment, categorizing datasets into three groups:

1. Syzkaller vs. repaired Syzkaller configuration files,
2. kAFL vs. repaired kAFL configuration files, and
3. defconfig vs. repaired defconfig configuration files. (these are obtained
from a [previous study](https://github.com/paulgazz/kmax/tree/master/scripts/krepair_evaluation).

The patch coverage results for each dataset are saved in the following files
within the `figure1/` directory:

- `syzkaller_krepair_experiment_j8.csv`
- `kafl_krepair_experiment_j8.csv`
- `defconfig_krepair_experiment_j8.csv`

These files are used by the **get_figure_1.sh** script to generate the bar chart
depicted in **Figure 1**.
To obtain patch coverage results for syzkaller and kAFL configuration files,
you can follow the steps outlined [here](replication_study/krepair_syzkaller_evaluation/README.md)
and [here](replication_study/krepair_kafl_evaluation/README.md), respectively.

To get Figure 1, you can run the following command:
```Bash
bash replication_study/figure1/get_figure_1.sh
```
> [!NOTE]
> This script outputs information about mean, lower and upper bounds of the confidence
intervals of the patch coverage of syzkaller, kAFL, and defconfig configuration files.
It will also provide pdf file that contains the bar chart of the results with
the name `patchcoverage.pdf` under `figure1/` directory.

## Bootability Study
We evaluated the bootability of the kernel images built with the configuration
files generated by utilities like allyesconfig, allnoconfig, and randconfig.

We generated 100 configuration files with the randconfig utility, providing it
random seed of epoch time via the `KCONFIG_SEED` environment variable, and also
provided a probability of a configuration option to be enabled with 50% probability
via the `KCONFIG_PROBABILITY` environment variable.

We used Linux-next version `v6.7` to compile the configuration files.
`test_100_randconfigs.py` script was used to generate configuration files with randconfig,
build kernel images with them, and try to boot the kernel images with QEMU.

We observed that 100% of the kernel images built with the configuration files
generated by the randconfig utility were not bootable.
Furthermore, we generated kernel images using configuration files generated by
allyesconfig and allnoconfig utilities on Linux-next version v6.7.
We observed that neither the kernel image built with the allyesconfig
configuration file nor the kernel image built with the allnoconfig configuration
file was bootable.

To replicate the bootability study, you can run the following command:
```Bash
python3 bootability_study/test_100_randconfigs.py
```
> [!NOTE]
> This script outputs a csv file named `bootability_study.csv` under `bootability_study/` directory.

# TABLE VIII: Bugs that depended on configuration variety to be found.
The `get_relationship.py` script is designed to extract the list of configuration options necessary for issuing syscalls that can trigger specific kernel bugs. By analyzing the relationship between kernel configurations and bug-triggering calls, the script helps evaluate whether configuration-aware fuzzing has enabled to trigger these bugs.

## Functionality

The script includes functionality to compile the kernel, but in its current state, it uses pre-built kernel images for both default and repaired configuration files. For each image, whether built with the default or repaired configuration files, it launches a virtual machine using QEMU. Once the virtual machine is running, the script transfers and executes reproducer files inside it.

The script determines whether the provided reproducer is a **C-reproducer** or a **syz-reproducer** by analyzing the file type. Based on the reproducer type and the specified relationship test in the configuration file, the script handles the processing as follows:

### C-reproducer
- If the relationship test is set to `reproducer`, the script processes the trace files generated during kernel execution.
- The processing includes:
  - Mapping trace file addresses to source code lines.
  - Identifying required kernel configuration options using `klocalizer`.

### syz-reproducer
- The script runs the reproducer using the command: <code>./syz-execprog -enable=all -repeat=0 -procs=6 reproducer_file</code>
- Trace file generation and processing are skipped.
- A warning is logged indicating that this functionality is not supported for syz-reproducers.

The timeout for executing reproducer files differs based on their type:
- **C-reproducers:** Timeout is set to 40 seconds, as they typically run quickly.
- **Syz-reproducers:** Timeout is set to 5 minutes, as they often require more time and are more likely to crash the operating system.

This distinction ensures the script adapts appropriately to the nature of the reproducer being tested.
<p>This functionality ensures that the script handles different reproducer types appropriately and provides clear feedback in the logs for unsupported operations.</p>


---

## Command-Line Arguments

The script accepts the following command-line arguments:

### `-c` or `--config_file` (required)
- The path to the configuration file (e.g., `test.json`).
- This file contains paths to the necessary files and directories for the script to function, including kernel source paths, output directories, Syzkaller binaries, and other dependencies.


> [!NOTE]
> As a sample config file, the `defaults.json` file inside the table8 folder can be used. It currently contains paths in the environmental setup that may be unique to every individual. However, once the necessary parameters are updated, the script will work perfectly fine. The parameters that needs to be updated are:

# Example Configuration File
- **`kernel_src`**: The path to the linux-next directory, is accessible inside `icse25/` directory
- **`path_config_default`**: The path to the default kernel configuration file. They can be found inside `icse25/configuration_files/syzbot_configuration_files/` directory
- **`path_config_repaired`**: The path to the repaired kernel configuration file. They can be found inside `icse25/configuration_files/repaired_configuration_files/` directory
- **`path_reproducer`**: The path to the reproducer file, either a C-reproducer or a syz-reproducer. They can be found inside the `icse25/experiments/extras/table8/kcov_trace_test` and `icse25/experiments/extras/table8/reproducer_test/`. If you would like to collect trace files, please make sure you set `relationship_test` option inside the defaults.json file to `kcov`, and you have set `path_reproducer` path to one of the reproducers inside the `kcov_trace_test/` directory.
- **`output`**: The path to the output directory where results will be stored. It does not have specific path. When this script was tested, the output directory was set to the parent directory of icse25.
- **`debian_image_src`**: The path to the Debian image source directory. It can be found inside `icse25/debian_image` folder.
- **`default_config_image`**: The path to the kernel image built with the default configuration. The kernel images will be provided in the icse25/kernel_images directory, there will be default and repaired folder which will contain corresponding image paths (built with default configs, and with repaired configs respectively). Please select one sample image directory from the default directory.
- **`repaired_config_image`**: The path to the kernel image built with the repaired configuration. Same as `default_config_image` option, but please select one sample from repaired directory.
- **`relationship_test`**: Specifies the type of test to perform:
  - **`reproducer`**: Does not process trace files but appends results to the CSV file. This mode checks whether the reproducer has crashed the VM or not. In the end it appends the result to the VM.
  - **`kcov`**: Does similar thing to `reproducer` option, but in addition to that, it processes trace files for C-reproducers and skips trace processing for syz-reproducers.
- **`icse_path`**: Simply absolute path to the `icse25/` directory

The other options do not need to be changed.


`table8/relationship-table.csv` can be used to provide right values to each option
in the configuration file provided to the script.
The table has the following structure:
`reproducer-file-path, default-config-path, repaired-config-path, default-kernel-image, repaired-kernel-image-path, mode`

---
## Command-Line Usage
To run the script after necessary modifications are made, the following command can be used:
```bash
python3 get_relationship.py -c defaults.json
```

## Outputs

### CSV File
- Records details of each test run, including:
  - Commit ID
  - Whether the kernel images booted in QEMU
  - Configuration options extracted for each test
  - Results for both default and repaired configurations


It will be located inside `icse25/get_results_output` directory

### Processed Trace Files
- `<config_type>.trace`: Memory addresses.
- `<config_type>.lines`: Lines with file paths.
- `<config_type>.kloc_deps`: Configuration options required for the syscall.


They will be located inside `icse25/get_results_output/trace_files` directory

### Log Files
- **`log_before_repro.log`**: Captures the state of VM logs before reproducer execution, stored in the `icse25/get_results_output` directory (as defined in the configuration file).
- **QEMU Logs**:
  - Log files (`qemu.log`) for each VM are saved into the corresponding parent directory of images.
