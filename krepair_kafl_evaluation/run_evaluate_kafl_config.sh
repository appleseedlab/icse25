#!/bin/bash

# example: bash /data1/paul/kmax/scripts/krepair_syzkaller_evaluation/paper/run_evaluate_syzkaller_config.sh linux/ c07ba878ca199a6089cdb323bf526adbeeb4201f x86_64 formulacache outdir_with_build_j/c07ba878ca199a6089cdb323bf526adbeeb4201f ~/Documents/syzkaller

set -x

# used to find other scripts called
script_dir=$(dirname $(realpath $0))

krepaironly=true
all=

if [ "$#" -lt 6 ]; then
	echo "Illegal number of parameters"
	exit -1
fi

linuxsrclone=${1}
linuxsrclone=$(realpath ${linuxsrclone})
commit=${2}
arch=${3}
formulacache=${4}
outdir=${5}

kafl_config_src=${6}
kafl_config_src=$(realpath ${kafl_config_src})

if [ -d $outdir ]; then
	echo "ERROR: output directory already exists"
	exit 1
else
	mkdir -p $outdir
fi
outdir=$(realpath $outdir)

build_flags=$7

patch=${outdir}/commit.patch

(
	cd ${linuxsrclone}
	git checkout -f $commit
)
(
	cd ${linuxsrclone}
	git clean -dfx
)
(
	cd ${linuxsrclone}
	git show >${patch}
)

# kafl config
config_outdir=${outdir}/kafl_config
mkdir ${config_outdir}

config=${config_outdir}/config
mv ${kafl_config_src} ${config}

results=${config_outdir}/results

bash ${script_dir}/evaluate_kafl_config.sh ${linuxsrclone} ${patch} ${config} ${arch} ${formulacache} ${results}
