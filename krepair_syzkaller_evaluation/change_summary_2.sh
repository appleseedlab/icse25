scriptsdir=$(dirname $0)

# set -x
changestudycsvpath=${1}
configsdir=${2}

if [ -z ${changestudycsvpath} ]; then
    echo "Usage: $0 <change-study-csv-path> <configs-dir>"
    echo "Example: $0 change-study.csv camera_ready/configuration_files/"
    exit 1
fi

if [ ! -f ${changestudycsvpath} ]; then
    echo "File not found: ${changestudycsvpath}"
    exit 1
fi

if [ ! -d ${configsdir} ]; then
    echo "Directory not found: ${configsdir}"
    exit 1
fi

echo "commit,configfile,changes"
# for configfile in allnoconfig defconfig; do
while IFS=, read -r commit configfile repairedconfig; do
	changepct=0
	repairedconfig=$(echo ${repairedconfig} | tr -d '\r')
	changes=$(python3 measure_change.py --original-config ${2}/syzbot_configuration_files/${configfile} ${2}/repaired_configuration_files/${repairedconfig} 2>/dev/null | jq .repaired[].change_wrt_original | paste -sd+ | bc -lq)
	echo -n ${configfile},
	echo -n ${repairedconfig},
	echo -n ${changes}
	echo

done <${changestudycsvpath}
