# data_tables folder

# Structure

|Subdirectory|Description|
|----|----|
|[Table_of_all_crashes.xlsx](Table_of_all_crashes.xlsx)|This file contains the data about all alarms found during experiments with and without configuration variety.|
|[Repaired-SYZKALLER Deduplicated Crash name+Trace(Bug Finding+Coverage).xlsx](Repaired-SYZKALLER Deduplicated Crash name+Trace(Bug Finding+Coverage).xlsx)|This file contains the data about deduplicated alarms found during experiments with and without configuration variety.|
|[Repaired-SYZKALLER Only Crash+Call Trace(Bug Finding+Coverage).xlsx](Repaired-SYZKALLER Only Crash+Call Trace(Bug Finding+Coverage).xlsx)|This file contains the data about all alarms found during experiments with and without configuration variety. It contains the name of the crash with the call trace of the crash.|

# Contents of Table_of_all_crashes.xlsx
|Column|Description|
|----|----|
|Crash name|the name of the crash|
|Full trace|the call trace of the crash derived from the respective syzkaller bug report|
|Tool|the tool that found the crash|
|Experiment|the experiment where the crash was found|
|Fuzzed Linux Commit ID|the commit ID of the Linux kernel that was being fuzzed|
|Patch Commit ID|the patch used for generating the configuration variety|
|Blocks covered|the number of basic blocks covered, only available for crashes found during the "Coverage" experiment|
|Syscalls executed|the number of system calls executed, only available for crashes found during the "Coverage" experiment|
|Config option count|the number of configuration options in the configuration file that was used to build the kernel for the experiment|
|Config file size(in bytes)|the size of the configuration file that was used to build the kernel for the experiment|
|Binary size(in Mbs)|the size of the kernel binary that was built for the experiment|
|Time taken to find|the time taken by the fuzzer to find the crash|
|Reproducer available|whether a reproducer was available for the crash|
|Reproducer type|the type of reproducer available for the crash (Can be either a C reproducer or Syz reproducer, a Syzkaller reproducer program)|
|Reproducer crashed on repaired config|whether the reproducer crashed on the kernel build with the repaired configuration file|
|Reproducer crashed on Syzkaller config|whether the reproducer crashed on the kernel build with the original Syzkaller configuration file|
|Previously unreported|whether the crash was previously unreported at the time of the experiment|
|Reported|whether the crash was reported to the Linux kernel maintainers by us|
|LKML Discussion|whether the crash was discussed on the Linux kernel mailing list|
|Developers Responded|whether the Linux kernel developers responded to the bug report|
|Developers Confirmed|whether the Linux kernel developers confirmed the bug|
|Developers Patched|whether the Linux kernel developers patched the bug|
|CVE Issued|whether a CVE was issued for the bug|
