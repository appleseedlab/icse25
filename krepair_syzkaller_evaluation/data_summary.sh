scriptsdir=$(dirname $0)

experimentdir=${1}

coverable_patches=${scriptsdir}/coverable_patches

echo "commit,configfile,builderrcode,patchcoverage,buildtime"
cat ${coverable_patches} | while read commit; do
	commitdir=$(ls -d ${experimentdir}/${commit})
	configdir=${commitdir}/syzkaller_config/results
	echo -n ${commit},
	echo -n syzkaller_config,
	# echo -n $(cat ${commitdir}/syzkaller_config/results/build.errcode),
	echo -n $(python3 ${scriptsdir}/patch_coverage.py ${configdir}/koverage_outfile | cut -d' ' -f4),
	# echo -n $(cat ${commitdir}/syzkaller_config/results/build.time | head -n1)
	echo
done

cat ${coverable_patches} | while read commit; do
	commitdir=$(ls -d ${experimentdir}/${commit})
	configdir=${commitdir}/syzkaller_config/results
	echo -n ${commit},
	echo -n krepair,
	if [[ -e ${configdir}/patch_covered ]]; then
		# echo -n $(cat ${commitdir}/syzkaller_config/results/build.errcode),
		echo -n $(python3 ${scriptsdir}/patch_coverage.py ${configdir}/koverage_outfile | cut -d' ' -f4),
		# echo -n $(cat ${commitdir}/syzkaller_config/results/build.time | head -n1)
	else
		if [[ -e ${configdir}/krepair_one ]]; then
			# builderrcode=$(cat ${commitdir}/syzkaller_config/results/repaired_build.errcode)
			# echo -n ${builderrcode},
			echo -n $(python3 ${scriptsdir}/patch_coverage.py ${configdir}/repaired_koverage_outfile | cut -d' ' -f4),
			# echo -n $(cat ${commitdir}/syzkaller_config/results/repaired_build.time | head -n1)
		else
			# echo -n n/a,
			ls ${configdir}/repaired_koverage_outfile.* >/dev/null 2>/dev/null
			echo -n $(python3 ${scriptsdir}/patch_coverage.py <(python3 ${scriptsdir}/total_coverage.py ${configdir}/repaired_koverage_outfile.*) | cut -d' ' -f4),
			# echo -n $(ls ${configdir}/repaired_build.time.* | xargs cat | grep -v Command | paste -sd+ | bc -lq)
		fi
	fi
	echo
done
