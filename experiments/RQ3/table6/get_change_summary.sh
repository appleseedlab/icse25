#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/../../../")"

default_change_study_csv="$SCRIPT_DIR/change_study.csv"
default_output_csv_file="$SCRIPT_DIR/change_of_summaries_bug_finding_coverage.csv"

change_study_csv=${1:-$default_change_study_csv}
output_csv_file=${2:-$default_output_csv_file}

bash $SCRIPT_DIR/change_summary.sh $change_study_csv > $output_csv_file
sed -i '1d' $output_csv_file
python3 $SCRIPT_DIR/get_percentage_change.py

echo "Written output to: $output_csv_file"
