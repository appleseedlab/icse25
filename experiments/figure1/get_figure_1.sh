echo "Artifact for Fig. 1: Average patch coverage of syzkaller, kAFL, and defconfig."

# get root of the repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

# to obtain syzkaller_config_patchcoverage.txt
grep "syzkaller_config" syzkaller_krepair_experiment_j8.csv | awk -F',' '{print $3}' > syzkaller_config_patchcoverage.txt

# to obtain krepair_patchcoverage.txt
grep "krepair" syzkaller_krepair_experiment_j8.csv | awk -F',' '{print $3}' > krepair_patchcoverage.txt

# to obtain kafl_config_patchcoverage.txt
grep "kafl_config" kafl_krepair_experiment_j8.csv | awk -F',' '{print $3}' > kafl_config_patchcoverage.txt

# to obtain kafl_krepair_patchcoverage.txt
grep "krepair" kafl_krepair_experiment_j8.csv | awk -F',' '{print $3}' > kafl_krepair_patchcoverage.txt

# to obtain defconfig_config_patchcoverage.txt
grep "defconfig" defconfig_krepair_experiment_j8.csv | awk -F',' '{print $4}' > defconfig_config_patchcoverage.txt

# to obtain defconfig_krepair_patchcoverage.txt
grep "krepair" defconfig_krepair_experiment_j8.csv | awk -F',' '{print $4}' > defconfig_krepair_patchcoverage.txt

python3 $REPO_ROOT/figure1/calculate_confidence_interval.py --syzkaller_file syzkaller_config_patchcoverage.txt --krepair_file krepair_patchcoverage.txt --kafl_file kafl_config_patchcoverage.txt --kafl_krepair_file kafl_krepair_patchcoverage.txt --defconfig_file defconfig_config_patchcoverage.txt --defconfig_krepair_file defconfig_krepair_patchcoverage.txt --output_file $REPO_ROOT/figure1/patchcoverage.pdf

echo "Saved the figure to $REPO_ROOT/figure1/patchcoverage.pdf"
