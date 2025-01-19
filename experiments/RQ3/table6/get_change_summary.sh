SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../../")"

change_study_csv="$SCRIPT_DIR/change_study.csv"
output_csv_file="$SCRIPT_DIR/change_of_summaries_bug_finding_coverage.csv"

bash $SCRIPT_DIR/../krepair_syzkaller_evaluation/change_summary_2.sh $change_study_csv > $output_csv_file
sed -i '1d' $output_csv_file
python3 $SCRIPT_DIR/get_percentage_change.py
