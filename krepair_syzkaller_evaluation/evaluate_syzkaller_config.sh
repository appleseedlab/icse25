#!/bin/bash

# example: bash /data1/anon/kmax/scripts/krepair_syzkaller_evaluation/paper/evaluate_syzkaller_config.sh linux/ c07ba878ca199a6089cdb323bf526adbeeb4201f x86_64 formulacache outdir_with_build_j/c07ba878ca199a6089cdb323bf526adbeeb4201f
set -x

# used to find other scripts called
script_dir=$(dirname $(realpath $0))

if [ "$#" -lt 6 ]; then
	echo "Illegal number of parameters"
	exit -1
fi

# timeouts for klocalizer
make_timeout=600
superc_timeout=600

# this is an already-cloned linux source directory that only this run
linuxsrclone=$1
linuxsrclone=$(realpath ${linuxsrclone})

# path to the patchfile
patch=$2
patch=$(realpath ${patch})

# path to the config file to evaluate
config=$3
config=$(realpath ${config})

# the linux architecture to use
arch=$4

# formula cache storage directory for klocalizer
formulacache=$5
formulacache=$(realpath ${formulacache})

# this is the directory where output and intermediate files go
outdir=$6
if [ -d $outdir ]; then
	echo "ERROR: output directory already exists"
	exit 1
else
	mkdir -p $outdir
fi
outdir=$(realpath $outdir)

echo "[+] read inputs: linuxsrclone=${linuxsrclone} patch=${patch} config=${config} arch=${arch} formulacache=${formulacache} outdir=${outdir}"

# 1. check the coverage of the input configuration
(
	cd ${linuxsrclone}
	git clean -dfx
) # clean the repo
koverage_time=${outdir}/koverage_time
koverage_scratch=${outdir}/koverage_scratch
koverage_outfile=${outdir}/koverage_outfile
(
	cd ${linuxsrclone}
	/usr/bin/time -f %e -o ${koverage_time} koverage --config ${config} --arch ${arch} --linux-ksrc ${linuxsrclone} --check-patch ${patch} --scratch-dir ${koverage_scratch} -o ${koverage_outfile}
)

echo "[+] Used koverage to check patch"

# 3. repair if needed
grep EXCLUDED ${koverage_outfile}
if [[ "$?" == "0" ]]; then
	touch ${outdir}/patch_uncovered

	krepair_time=${outdir}/krepair.time
	krepair_configs=${outdir}/krepair_configs
	krepair_report=${outdir}/krepair_report
	(
		cd ${linuxsrclone}
		echo "[+] Using klocalizer"
		/usr/bin/time -f %e -o ${krepair_time} klocalizer -v --arch ${arch} --repair ${config} --include-mutex ${patch} --build-timeout ${make_timeout} --superc-timeout ${superc_timeout} --output ${krepair_configs} --coverage-report ${krepair_report} --formulas ${formulacache}
	)
	if [[ "$?" == 0 ]]; then
		numconfigs=$(ls ${krepair_configs} | wc -l)
		if [[ ${numconfigs} -eq 1 ]]; then
			discovered_arch=$(ls ${krepair_configs}/*.config | head -n1 | xargs basename | cut -f1 -d\. | cut -f2 -d-)
			touch ${outdir}/krepair_one
			repaired_config=$(find ${krepair_configs} -type f)
			# 4. check the coverage of the repaired configuration
			repaired_koverage_time=${outdir}/repaired_koverage_time
			repaired_koverage_scratch=${outdir}/repaired_koverage_scratch
			repaired_koverage_outfile=${outdir}/repaired_koverage_outfile
			(
				cd ${linuxsrclone}
				/usr/bin/time -f %e -o ${repaired_koverage_time} koverage --config ${repaired_config} --arch ${discovered_arch} --linux-ksrc ${linuxsrclone} --check-patch ${patch} --scratch-dir ${repaired_koverage_scratch} -o ${repaired_koverage_outfile}
			)

			grep EXCLUDED ${repaired_koverage_outfile}
			if [[ -f ${repaired_koverage_outfile} && "$?" != "0" ]]; then
				touch ${outdir}/repaired_patch_covered
			else
				touch ${outdir}/repaired_patch_uncovered
			fi
			# added here
			if [[ "${build_after}" != "" ]]; then
				# 5. build
				repaired_build_time=${outdir}/repaired_build.time
				repaired_build_size=${outdir}/repaired_build.size
				repaired_build_out=${outdir}/repaired_build.out
				repaired_build_errcode=${outdir}/repaired_build.errcode
				repaired_olddefconfig=${outdir}/repaired_olddefconfig
				(
					cd ${linuxsrclone}
					git clean -dfx
				) # clean the repo
				cp ${repaired_config} ${linuxsrclone}/.config
				sed -i 's/CONFIG_PHYSICAL_START=0/CONFIG_PHYSICAL_START=0x1000000/' ${linuxsrclone}/.config
				(
					cd ${linuxsrclone}
					make.cross ARCH=${discovered_arch} olddefconfig
				) # clean the repo
				cp ${linuxsrclone}/.config ${repaired_olddefconfig}
				#(cd ${linuxsrclone}; /usr/bin/time -f %e -o ${repaired_build_time} make.cross ${build_flags} ARCH=${discovered_arch} > ${repaired_build_out} 2>&1; echo ${?} > ${repaired_build_errcode})
				# measure size of build
				#(cd ${linuxsrclone}; ls -lSrh arch/*/boot; find | grep "\.ko$" | xargs ls -lSrh) > ${repaired_build_size}
			fi
			# added here
		else
			touch ${outdir}/krepair_not_one

			ls ${krepair_configs}/*.config | while IFS= read -r repaired_config; do
				discovered_arch=$(echo $repaired_config | xargs basename | cut -f1 -d\. | cut -f2 -d-)
				basename=$(basename $repaired_config)

				# 4. check the coverage of the repaired configuration
				repaired_koverage_time=${outdir}/repaired_koverage_time.${basename}
				repaired_koverage_scratch=${outdir}/repaired_koverage_scratch.${basename}
				repaired_koverage_outfile=${outdir}/repaired_koverage_outfile.${basename}
				(
					cd ${linuxsrclone}
					/usr/bin/time -f %e -o ${repaired_koverage_time} koverage --config ${repaired_config} --arch ${discovered_arch} --linux-ksrc ${linuxsrclone} --check-patch ${patch} --scratch-dir ${repaired_koverage_scratch} -o ${repaired_koverage_outfile}
				)
			done

			repaired_koverage_total=${outdir}/repaired_koverage_outfile
			python3 ${script_dir}/total_coverage.py -o ${repaired_koverage_total} ${outdir}/repaired_koverage_outfile.*

			grep EXCLUDED ${repaired_koverage_total}
			if [[ -f ${repaired_koverage_total} && "$?" != "0" ]]; then
				touch ${outdir}/repaired_patch_covered
			else
				touch ${outdir}/repaired_patch_uncovered
			fi
			# added here
			if [[ "${build_after}" != "" ]]; then
				ls ${krepair_configs}/*.config | while IFS= read -r repaired_config; do
					discovered_arch=$(echo $repaired_config | xargs basename | cut -f1 -d\. | cut -f2 -d-)
					basename=$(basename $repaired_config)
					# 5. build
					repaired_build_time=${outdir}/repaired_build.time.${basename}
					repaired_build_size=${outdir}/repaired_build.size.${basename}
					repaired_build_out=${outdir}/repaired_build.out.${basename}
					repaired_build_errcode=${outdir}/repaired_build.errcode.${basename}
					repaired_olddefconfig=${outdir}/repaired_olddefconfig.${basename}
					(
						cd ${linuxsrclone}
						git clean -dfx
					) # clean the repo
					cp ${repaired_config} ${linuxsrclone}/.config
					sed -i 's/CONFIG_PHYSICAL_START=0/CONFIG_PHYSICAL_START=0x1000000/' ${linuxsrclone}/.config
					(
						cd ${linuxsrclone}
						make.cross ARCH=${discovered_arch} olddefconfig
					) # clean the repo
					cp ${linuxsrclone}/.config ${repaired_olddefconfig}
					# (cd ${linuxsrclone}; /usr/bin/time -f %e -o ${repaired_build_time} make.cross ${build_flags} ARCH=${discovered_arch} > ${repaired_build_out} 2>&1)
					# measure size of build
					# (cd ${linuxsrclone}; ls -lSrh arch/*/boot; find | grep "\.ko$" | xargs ls -lSrh) > ${repaired_build_size}
				done
			fi
			# added here
		fi
	else
		touch ${outdir}/krepair_errored
	fi
else
	touch ${outdir}/patch_covered
fi
