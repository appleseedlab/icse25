#!/bin/bash

# example: bash run_many_syzkaller_evaluations.sh coverable_patches linux/ x86_64 formulacache outdir/ ~/Documents/syzkaller |& tee out

# example: bash run_many_syzkaller_evaluations.sh localhost:45678 /home/sanan/linux/ x86_64 formulacache ./outdir/ ~/Documents/syzkaller-3 |& tee out

# example:
# java superc.util.FilenameService -server 45678 /data1/anon/kmax/scripts/krepair_syzkaller_evaluation/paper/coverable_patches &
# for sdd in {1..3}; do for instance in {0..9}; do linuxdir=/data${sdd}/test_experiment/inputs/linux${instance}; outdir=/data${sdd}/test_experiment/krepair_out${instance}; log=/data${sdd}/test_experiment/krepair_out${instance}.log; source=localhost:45678; bash /data1/anon/kmax/scripts/krepair_evaluation/paper/run_many_evaluations.sh ${source} ${linuxdir} x86_64 /data1/anon/kmax/scripts/krepair_evaluation/assets_linuxv513/build_targets.json formulacache ${outdir} -j8 > ${log} 2>&1 & sleep 1; done; done

#set -x

usage() {
    echo "Usage: $0 [source] [linuxsrclone] [arch] [formulacache] [outdir] [syzkallersrc]"
    echo "source: the source of commit ids, either a /path/to/a/sample/file or the server:port of a FilenameService"
    echo "linuxsrclone: the path to the linux source code clone"
    echo "arch: the architecture of the linux source code"
    echo "formulacache: the path to the formula cache"
    echo "outdir: the path to the output directory"
    echo "syzkallersrc: the path to the syzkaller source code"
}

echo "Executing run_many_syzkaller_evaluations..."

# used to find other scripts called
script_dir=$(dirname $(realpath $0))
default_linux_src=$(realpath "${script_dir}/../../../../linux-next")
default_formulacache="${script_dir}/formulacache"
default_arch="x86_64"
default_syzkaller_src=$(realpath "${script_dir}/../../../../syzkaller")
default_outdir="${script_dir}/outdir"

# the source of commit ids, either a /path/to/a/sample/file (no colon symbol permitted) or the server:port of a FilenameService
source=${1:-"${script_dir}/coverable_patches"}

linuxsrclone=${2:-$default_linux_src}
linuxsrclone=$(realpath ${linuxsrclone})

arch=${3:-$default_arch}

formulacache=${4:-$default_formulacache}
formulacache=$(realpath ${formulacache})

outdir=${5:-$default_outdir}
outdir="${outdir}/$(date +%s)"
mkdir -p $outdir
outdir=$(realpath $outdir)

syzkallersrc=${6:-$default_syzkaller_src}
syzkallersrc=$(realpath $syzkallersrc)

# Preliminary checks
if [ ! -d ${linuxsrclone} ]; then
    echo "Error: ${linuxsrclone} is not a directory"
    usage
    exit 1
fi

if [ ! -d ${syzkallersrc} ]; then
    echo "Error: ${syzkallersrc} is not a directory"
    usage
    exit 1
fi

run_eval() {
	commit=$1
	outdir_commit=${outdir}/${commit}
	bash ${script_dir}/run_evaluate_syzkaller_config.sh ${linuxsrclone} ${commit} ${arch} ${formulacache} ${outdir_commit} ${syzkallersrc}
}

# assume it's a server:port if there is a colon
if [[ "${source}" == *":"* ]]; then
	server=$(echo ${source} | cut -f1 -d:)
	port=$(echo ${source} | cut -f2 -d:)
	while true; do
		commit=$(java superc.util.FilenameService -client $server $port)
		exit_code=$?
		if [ "$exit_code" -ne 0 ]; then
			exit $exit_code
		fi
		run_eval $commit
	done
else
	sample=${source}
	cat ${sample} | while read commit; do
		run_eval $commit
	done
fi
