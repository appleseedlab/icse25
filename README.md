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

Reports of the bugs found with fuzzing with configuration variety, and discussions
with the kernel maintainers can be found [here](
https://lore.kernel.org/lkml/?q=Sanan+Hasanov).

---

# Purpose

The purpose of the artifacts is to provide a reproducible environment for the
experiments conducted in the paper.
Dockerized environment is provided to ensure that the experiments can be
reproduced on any system without any dependency issues.
In addition, the scripts are provided to automate the process of running the
experiments along with the detailed instructions.

Therefore, we would like to apply for the following badges:
- Available
- Functional
- Reusable

---

# Provenance

#TODO: Add zenodo link
The artifacts can be found [here]()
Link to the preprint of the paper can be found [here](https://paulgazzillo.com/papers/icse25.pdf)

---

# Setup

## :floppy_disk: Hardware Requirements
A workstation with at least 16GB of RAM and 100GB of free disk space is recommended.

## :computer: Software Requirements
The experiments are conducted in a Docker container. Therefore, you need to have
Docker installed on your system. You can download Docker from the [official website](https://docs.docker.com/get-docker/).

---

# Usage

## :wrench: Prerequisites
Before running the experiments, please make sure that you have Python 3.9 or later
installed on your system. You can download Python from the [official website](https://www.python.org/downloads/).
Next, you need to run setup.sh script to install the required dependencies.
```bash
sudo ./setup.sh
```

## :rocket: Quick Start
To get a demo of the fuzzing experiments with and without configuration variety,
you can run the following command to conduct the experiment on a default and a
repaired kernel image for 15 minutes:
```bash
./fuzz.sh
```
