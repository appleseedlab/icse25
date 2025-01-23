# Main Experiment: Fuzzing with and without Configuration Variety

This subdirectory contains the **main fuzzing scripts** to conduct experiments with and without configuration variety.

We provide three ways to replicate the experimental setup and results:

1. **Quick-start**: Perform fuzzing experiments using **syzkaller**
on prebuilt kernel images, one built with a default and the other one built with
a repaired configuration file.

2. **Prebuilt Kernel Images**: Reproduce the entire fuzzing experiments using
prebuilt kernel images built with default and repaired configuration files.
This by default will take 12 hours to conduct a fuzzing run on each kernel image
for the entirety of 100 prebuilt kernel images that we provide.

3. **Full Experimental Setup**: Perform the entire experimental setup from scratch,
including repairing configuration files, building kernel images, and conducting
fuzzing experiments with and without configuration variety using **syzkaller**.
For each parameter combination, this takes approximately around 1 hour to generate
configuration files, build kernel images, in addition to 12 hours to conduct
fuzzing runs on each kernel image.

---

## Scripts Overview

### 1. `fuzz.sh`
**Purpose:** A quick-start script to perform fuzzing experiments.

- **What it does:**
  - Executes fuzzing in parallel on:
    - A kernel image built with the **default configuration**.
    - A kernel image built with a **repaired configuration**.

---

### 2. `fuzzing_experiments.sh`
**Purpose:** Reproduces experiments using either from scratch with **full**
fuzzing mode or with the provided kernel images with **prebuilt** mode.

- **What it does:**
  - It has two modes:
    - **Prebuilt mode**: Reproduces the experiments using prebuilt kernel images.
    - **Full mode**: Reproduces the experiments from scratch.

  - **Prebuilt mode:**
    - Conducts fuzzing experiments using prebuilt kernel images.
    - Suitable for **quickly replicating results** without needing to rebuild kernels.

  - **Full mode:**
    - Repairs default syzkaller configuration files with given commit patches.
    - Builds kernel images with default and repaired configuration files.
    - Conducts fuzzing experiments.

---

## Highlights
- Prebuilt kernel images and configuration files used in the experiments are provided for convenience.
- The artifacts and resources provided aim to streamline the reproduction of the experiments.

---

# Structure
|Subdirectory|Section|
|----|----|
|[fuzz.sh](fuzz.sh)|A quick-start script to run fuzzing with syzkaller using prebuilt kernel images with default and repaired configurations.|
|[fuzzing_experiments.sh](fuzzing_experiments.sh)|The main fuzzing script that allows reproducing the study of the paper with two modes: prebuilt and full|
|[fuzzing_parameters.csv](fuzzing_parameters.csv)|CSV file that contains commit ids to repair config files with, original syzbot configuration files, repaired configuration files, linux-next tags that fuzzed kernel images were built with, and names of kernel images, default and repaired|

# Usage

## Quick-start
To have a jumpstart and run fuzzing with configuration variety,
execute the quick-start script `fuzz.sh` as follows:
```Bash
./fuzz.sh
```
This will by default run fuzzing experiments using prebuilt kernel images with default and repaired configurations
in parallel and save results in the `fuzz_output/` directory.

## Replicate the study using prebuilt kernel images
To replicate the entire fuzzing experiments using prebuilt kernel images,
use the script `fuzzing_experiments.sh` as follows:
```Bash
./fuzzing_experiments.sh prebuilt all
```
We provide two parameters to the script:
- `prebuilt`: to use prebuilt kernel images.
- `all`: to run all types of experiments(default, repaired)
for all prebuilt kernel images.

The script also has other optional parameters:
```
[fuzz_type] - Type of fuzzing to run. Options: prebuilt, full

prebuilt - Use prebuilt kernel images to run fuzzing experiments.
full - Run fuzzing experiments from scratch.

[experiment_type] - Type of experiment to run. Options: all, default, repaired

all - Run all types of experiments(default, repaired) for all prebuilt kernel images
consecutively.
default - Run fuzzing with default configurations for all prebuilt kernel images.
repaired - Run fuzzing with repaired configurations for all prebuilt kernel images.

[csv-file] - Path to the CSV file that contains the parameters for fuzzing experiments.

Parameters include:
- commit ids to repair config files with
- original syzbot configuration files
- repaired configuration files
- linux-next tags that fuzzed kernel images were built with
- names of kernel images, default and repaired

[linux-next path] - Path to the linux-next repository.
[syzkaller path] - Path to the syzkaller repository.
[debian image path] - Path to the debian image.
[kernel images path] - Path to the provided prebuilt kernel images.
[output path] - Path to the output directory to save the results.
[fuzzing-time] - Timeout for fuzzing. Receives values the same way as 'timeout' command.
[procs] - Number of parallel processes to run fuzzing.
[vm_count] - Number of VMs to use for fuzzing.
[cpu] - Number of CPUs to use for fuzzing.
[mem] - Amount of memory to use for fuzzing.
```
> [!NOTE]
> To only provide some of the optional parameters, use "" for the parameters you want to skip.
> For example, to only provide the `linux-next path` parameter, use:
> ```Bash
> ./fuzzing_experiments.sh "" "" "" /path/to/linux-next
> ```
> This will skip the first three parameters, the parameters after the `linux-next path`
parameter, and only provide the `linux-next path` parameter.

The script with the provided command above will run each fuzzing run on one kernel
image built with default and repaired configurations for 50 runs.

The results will be saved in the `fuzz_output_prebuilt/` directory.

> [!IMPORTANT]
> Each fuzzing run takes around 12 hours to complete by default.
> By default, the script runs 100 fuzzing runs for 100 prebuilt
kernel images(50 default and 50 repaired).

## Replicate the study from scratch
To replicate the entire fuzzing experiments from scratch, use the script
`fuzzing_experiments.sh` as follows:

```Bash
./fuzzing_experiments.sh full all
```

We provide two parameters to the script:
- `full`: to run every step of the experimental setup from scratch.
- `all`: to run all types of experiments(default, repaired).

The script reads `fuzzing_parameters.csv` file to get patch commit ids to repair configuration files with,
original syzbot configuration files, linux-next commit ids that fuzzed kernel images were built with.

It then repairs the configuration files(if the selected mode is 'repaired'),
builds kernel images, and conducts fuzzing runs.

The results are saved in the `fuzz_output_full/` directory.

> [!IMPORTANT]
> Each fuzzing run takes around 12 hours to complete by default.
> Additionally, building kernel images and repairing configuration files
takes around 1 hour for each parameter combination.
> By default, the script runs 100 fuzzing runs for 100 prebuilt
kernel images(50 default and 50 repaired).
