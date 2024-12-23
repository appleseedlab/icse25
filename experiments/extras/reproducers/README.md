# Getting Avaiable Reproducer Files for the Bugs Found with Repaired Configurations

## Directory Structure
#TODO

## Getting Reproducer Files
To get the reproducers files, you can use the following command:

```bash
docker exec -it artifacts-container bash -c "bash ./icse25/experiments/extras/reproducers/collect_reproducers.sh ./outdir/ ./experiments/extras/reproducers/repaired_reproducers.csv ./repaired_bugs/"
```

This will collect the reproducers files for the bugs found with repaired configurations. The files will be stored in the `./outdir/` directory.
