# Main Experiment: Fuzzing with and without Configuration Variety

This subdirectory contains the **main fuzzing scripts** to conduct experiments with and without configuration variety.

The experimental setup and results from our study can be **replicated and reused** using the three scripts detailed below:

---

## Scripts Overview

### 1. `fuzz.sh`
**Purpose:** A quick-start script to perform fuzzing experiments using **syzkaller**.

- **What it does:**
  - Executes fuzzing in parallel on:
    - A kernel image built with the **default configuration**.
    - A kernel image built with a **repaired configuration**.
- Ideal for **quick exploration** of fuzzing behavior.

---

### 2. `fuzzing_experiments_prebuilt.sh`
**Purpose:** Reproduces experiments using **prebuilt kernel images**.

- **What it uses:**
  - Kernel images:
    - Built with the **default configuration**.
    - Built with the **repaired configuration** used in the paper's experiments.
- Suitable for **replicating results** without needing to rebuild kernels.

---

### 3. `fuzzing_experiments_full.sh`
**Purpose:** Performs the **entire experimental setup from scratch**.

- **What you need:**
  - Manually selected **syzbot configuration files** (provided).
  - **Patch commit IDs** for repairing configuration files.
  - **linux-next commit IDs** used in the experiments.
- **Automates:**
  - Repairing configuration files.
  - Building kernel images.
  - Conducting fuzzing experiments with and without configuration variety using **syzkaller**.

---

## Highlights
- Prebuilt kernel images and configuration files used in the experiments are provided for convenience.
- The artifacts and resources provided aim to streamline the replication of the experiments.

---

# Structure
|Subdirectory|Section|
|----|----|
|[fuzz.sh](fuzz.sh)|A quick-start script to run fuzzing with syzkaller using prebuilt kernel images with default and repaired configurations.|
|[fuzzing_experiments_prebuilt.sh](fuzzing_experiments_prebuilt.sh)|Script to perform fuzzing with and without configuration variety using prebuilt kernel images.|
|[fuzzing_experiments_full.sh](fuzzing_experiments_full.sh)|Script to run the full experimental setup, including repairing configurations, building kernels, and fuzzing.|
|[fuzzing_parameters.csv](fuzzing_parameters.csv)|CSV file that contains commit ids to repair config files with, original syzbot configuration files, repaired configuration files, and linux-next tags that fuzzed kernel images were built with.|
|[output](output/)|The folder where the results of fuzzing runs are saved.|

# Usage
The following command can be used to run the script that performs fuzzing without configuration variety using syzkaller:
```Bash
bash ./experiments/fuzzing/fuzzing_experiments_prebuilt.sh default ./experiments/fuzzing/fuzzing_parameters.csv ./linux-next/ ./syzkaller/ ./debian_image/ ./experiments/fuzzing/output/ 12h
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
- ./experiments/fuzzing/output/ - the path to the directory where the results of the
fuzzing experiments will be saved.
