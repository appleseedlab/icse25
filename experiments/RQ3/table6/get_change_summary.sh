SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

bash $SCRIPT_DIR/../krepair_syzkaller_evaluation/change_summary_2.sh $SCRIPT_DIR/change_study.csv > $SCRIPT_DIR/change_of_summaries_bug_finding_coverage.csv
python3 $SCRIPT_DIR/get_percentage_change.py
