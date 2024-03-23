scriptsdir=$(dirname $0)

# set -x
changestudycsvpath=${1}
echo "commit,configfile,changes"
# for configfile in allnoconfig defconfig; do
while IFS=, read -r commit configfile repairedconfig; do
	changepct=0
	repairedconfig=$(echo ${repairedconfig} | tr -d '\r')
	changes=$(python3 /home/anon/opt/icse25/krepair_syzkaller_evaluation/measure_change.py --original-config /home/anon/research/syzbot_configuration_files/${configfile} /home/anon/research/repaired_configuration_files/${repairedconfig} 2>/dev/null | jq .repaired[].change_wrt_original | paste -sd+ | bc -lq)
	echo -n ${configfile},
	echo -n ${repairedconfig},
	echo -n ${changes}
	echo

done <${changestudycsvpath}
