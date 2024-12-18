echo "Artifact for Fig. 1: Average patch coverage of syzkaller, kAFL, and defconfig."

# get root of the repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

# to obtain syzkaller_config_patchcoverage.txt
grep "syzkaller_config" $SCRIPT_DIR/syzkaller_krepair_experiment_j8.csv | awk -F',' '{print $3}' > $SCRIPT_DIR/syzkaller_config_patchcoverage.txt

# to obtain krepair_patchcoverage.txt
grep "krepair" $SCRIPT_DIR/syzkaller_krepair_experiment_j8.csv | awk -F',' '{print $3}' > $SCRIPT_DIR/krepair_patchcoverage.txt

# to obtain kafl_config_patchcoverage.txt
grep "kafl_config" $SCRIPT_DIR/kafl_krepair_experiment_j8.csv | awk -F',' '{print $3}' > $SCRIPT_DIR/kafl_config_patchcoverage.txt

# to obtain kafl_krepair_patchcoverage.txt
grep "krepair" $SCRIPT_DIR/kafl_krepair_experiment_j8.csv | awk -F',' '{print $3}' > $SCRIPT_DIR/kafl_krepair_patchcoverage.txt

# to obtain defconfig_config_patchcoverage.txt
grep "defconfig" $SCRIPT_DIR/defconfig_krepair_experiment_j8.csv | awk -F',' '{print $4}' > $SCRIPT_DIR/defconfig_config_patchcoverage.txt

# to obtain defconfig_krepair_patchcoverage.txt
grep "krepair" $SCRIPT_DIR/defconfig_krepair_experiment_j8.csv | awk -F',' '{print $4}' > $SCRIPT_DIR/defconfig_krepair_patchcoverage.txt

python3 $REPO_ROOT/figure1/calculate_confidence_interval.py --syzkaller_file $SCRIPT_DIR/syzkaller_config_patchcoverage.txt --krepair_file $SCRIPT_DIR/krepair_patchcoverage.txt --kafl_file $SCRIPT_DIR/kafl_config_patchcoverage.txt --kafl_krepair_file $SCRIPT_DIR/kafl_krepair_patchcoverage.txt --defconfig_file $SCRIPT_DIR/defconfig_config_patchcoverage.txt --defconfig_krepair_file $SCRIPT_DIR/defconfig_krepair_patchcoverage.txt --output_file $SCRIPT_DIR/patchcoverage.pdf

echo "Saved the figure to $SCRIPT_DIR/patchcoverage.pdf"
