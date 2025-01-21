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
- The artifacts and resources provided aim to streamline the replication of the experiments.

---

# Structure
|Subdirectory|Section|
|----|----|
|[fuzz.sh](fuzz.sh)|A quick-start script to run fuzzing with syzkaller using prebuilt kernel images with default and repaired configurations.|
|[fuzzing_experiments.sh](fuzzing_experiments_full.sh)|Script to run the full experimental setup, including repairing configurations, building kernels, and fuzzing.|
|[fuzzing_parameters.csv](fuzzing_parameters.csv)|CSV file that contains commit ids to repair config files with, original syzbot configuration files, repaired configuration files, linux-next tags that fuzzed kernel images were built with, and names of kernel images, default and repaired|
|[output](output/)|The folder where the results of fuzzing runs are saved.|

# Usage

## Quick-start
To have a jumpstart and run fuzzing with configuration variety,
execute the quick-start script `fuzz.sh` as follows:
```Bash
./fuzz.sh
```
This will by default run fuzzing experiments using prebuilt kernel images with default and repaired configurations
in paralllel and save results in the `fuzz_output/` directory.

## Replicate the study using prebuilt kernel images
To replicate the entire fuzzing experiments using prebuilt kernel images,
use the script `fuzzing_experiments.sh` as follows:
```Bash
./fuzzing_experiments.sh prebuilt default &
./fuzzing_experiments.sh prebuilt repaired &
```
This will run each fuzzing run on one kernel image built with a default configuration and another with a repaired configuration
for 50 runs.
The results will be saved in the `fuzz_output_prebuilt/` directory.
> [!IMPORTANT]
> Each fuzzing run takes around 12 hours to complete by default.
> By default, the script runs 100 fuzzing runs for 100 prebuilt
kernel images(50 default and 50 repaired).

## Replicate the study from scratch
To replicate the entire fuzzing experiments from scratch, use the script
`fuzzing_experiments.sh` as follows:
```Bash
./fuzzing_experiments.sh full default &
./fuzzing_experiments.sh full repaired &
```
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
