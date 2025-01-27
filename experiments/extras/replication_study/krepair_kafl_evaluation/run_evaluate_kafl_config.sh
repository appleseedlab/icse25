#!/bin/bash

# example: bash ./run_evaluate_kafl_config.sh linux/ c07ba878ca199a6089cdb323bf526adbeeb4201f x86_64 formulacache ./outdir/c07ba878ca199a6089cdb323bf526adbeeb4201f ./kafl.config

# set -x

# used to find other scripts called
script_dir=$(dirname $(realpath $0))

krepaironly=true
all=

default_linux_src=$(realpath "${script_dir}/../../../linux-next")
default_outdir="${script_dir}/outdir"
default_kaflsrc="${script_dir}/kafl.config"
mkdir -p $default_outdir

linuxsrclone=$(realpath ${1-$default_linux_src})
commit=${2}
arch=${3}
formulacache=${4}
outdir=${5-$default_outdir}
kafl_config_src=$(realpath ${6-$default_kaflsrc})

if [ -d $outdir ]; then
	echo "ERROR: output directory already exists"
	exit 1
else
	mkdir -p $outdir
fi

if [ ! -d $linuxsrclone ]; then
    echo "ERROR: linux source directory does not exist"
    exit 1
fi

if [ ! -f $kafl_config_src ]; then
    echo "ERROR: kafl config file does not exist"
    exit 1
fi

outdir=$(realpath $outdir)

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
cp ${kafl_config_src} ${config}

results=${config_outdir}/results

bash ${script_dir}/evaluate_kafl_config.sh ${linuxsrclone} ${patch} ${config} ${arch} ${formulacache} ${results}
