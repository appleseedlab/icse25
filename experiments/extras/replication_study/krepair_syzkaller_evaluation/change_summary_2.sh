SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../..")"

syzbot_configuration_files_dir="${REPO_ROOT}/configuration_files/syzbot_configuration_files"
repaired_configuration_files_dir="${REPO_ROOT}/configuration_files/repaired_configuration_files"
krepair_syzkaller_evaluation_dir="${SCRIPT_DIR}"

if [ ! -d ${syzbot_configuration_files_dir} ]; then
    echo "Error: ${syzbot_configuration_files_dir} does not exist"
    exit 1
fi

if [ ! -d ${repaired_configuration_files_dir} ]; then
    echo "Error: ${repaired_configuration_files_dir} does not exist"
    exit 1
fi

changestudycsvpath=${1}

if [ -z ${changestudycsvpath} ]; then
    echo "Usage: $0 <change-study-csv-path>"
    echo "Example: $0 change_study.csv"
    exit 1
fi

# for configfile in allnoconfig defconfig; do
while IFS=, read -r commit configfile repairedconfig; do
	changepct=0
	repairedconfig=$(echo ${repairedconfig} | tr -d '\r')
	changes=$(python3 ${krepair_syzkaller_evaluation_dir}/measure_change.py --original-config ${syzbot_configuration_files_dir}/${configfile} ${repaired_configuration_files_dir}/${repairedconfig} 2>/dev/null | jq .repaired[].change_wrt_original | paste -sd+ | bc -lq)
	echo -n ${configfile},
	echo -n ${repairedconfig},
	echo -n ${changes}
	echo

done <${changestudycsvpath}
