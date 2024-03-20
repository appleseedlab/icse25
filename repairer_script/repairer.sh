time1=00:00:00
time2=03:00:00
time3=06:00:00
time4=09:00:00
time5=12:00:00
time6=15:00:00
time7=18:00:00
time8=21:00:00
time9=23:59:59

RED='\033[0;31m'
NC='\033[0m'

# start and end dates
d=$1;
e=$2;

# Configuration file we wanna use
config_file=$3

current_date=$(date +'%m%d%Y')

# Path to Linux directory
dir_linux_next=/home/anon/linux-next

# Path to Syzkaller directory
dir_syzkaller=/home/anon/opt/syzkaller

#source ~/env_kmax/bin/activate



# Path to saved diff files that are used
output_of_diff=/home/anon/research/coverage_commit_diff_files/;

# Path to saved koverage result files
output_of_koverage=/home/anon/research/coverage_commit_koverage_files/;

# Path to saved repaired koverage result files
output_of_repaired_koverage_path=/home/anon/research/coverage_commit_configuration_files/;

#output_of_repaired_koverage_file_path=/home/anon/research/coverage_commit_repaired_koverage_files;



total_excluded=0
total_repaired_excluded=0

if [ $# -ne 3 ]; then
                echo "[!] Usage: ./program start_date end_date config_file"
                exit 1
fi

diff=1

arr=()

get_commits(){
        d=$1
        time1=$2
        time2=$3
        output_of_diff=/home/anon/research/coverage_commit_diff_files/;
        output_of_koverage=/home/anon/research/coverage_commit_koverage_files/;
        output_of_repaired_koverage_path=/home/anon/research/coverage_commit_repaired_koverage_files/;
        output_of_repaired_koverage_file_path=/home/anon/research/coverage_commit_configuration_files/;
        config_file=$4

        config_name=$(basename "$config_file")
        #git checkout -f master
        echo "TIME PERIOD: $d $time1 - $time2"

        # do tests for the first period
        echo "logs of $time1 and $time2:"

        #git log --after="$d $time1" --before="$d $time2" --pretty=fuller --no-merges --date=local master | grep ^commit
        commit_count=`git log --after="$d $time1" --before="$d $time2" --pretty=fuller --no-merges --date=local master | grep ^commit | wc -l`
        arr+=($(git log --after="$d $time1" --before="$d $time2" --pretty=fuller --no-merges --date=local master | grep ^commit | awk -F' ' {'print $2'}))
        #echo "\nArray elements: \n"
        #echo "${arr[*]}"
        if [ $commit_count == 0 ]; then
                echo "NO COMMITS FOR THE GIVEN TIME RANGE..."
                break
        fi
}

while [ "$d" != $e ]; do
                get_commits "$d" "$time1" "$time2" "$config_file"
                get_commits "$d" "$time2" "$time3" "$config_file"
                get_commits "$d" "$time3" "$time4" "$config_file"
                get_commits "$d" "$time4" "$time5" "$config_file"
                get_commits "$d" "$time5" "$time6" "$config_file"
                get_commits "$d" "$time6" "$time7" "$config_file"
                get_commits "$d" "$time7" "$time8" "$config_file"
                get_commits "$d" "$time8" "$time9" "$config_file"
                # perform_operations "$d" "$time1" "$time2" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                # perform_operations "$d" "$time2" "$time3" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                # perform_operations "$d" "$time3" "$time4" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                # perform_operations "$d" "$time4" "$time5" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                # perform_operations "$d" "$time5" "$time6" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                # perform_operations "$d" "$time6" "$time7" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                # perform_operations "$d" "$time7" "$time8" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                # perform_operations "$d" "$time8" "$time9" "$output_of_diff" "$output_of_koverage" "$output_of_repaired_koverage_path" $total_excluded $total_repaired_excluded
                #git log --after="$d 12:00:00" --before="$d 15:00:00" --pretty=fuller --reverse --no-merges --date=local master | grep ^commit
                d=$(date -I -d "$d + 1 day")
done

second_arr=()


#second_arr=$(for i in {1..6}; do printf "%s\n" ${arr[@]} | shuf | head -1; done)
arr=( $(shuf -e "${arr[@]}") )

rand_number=( $(shuf -i 1-30 -n1) )

echo "[+] RANDOM NUMBER: $rand_number"
rn=$((rand_number))

second_arr=( $(for i in $(seq 1 "$rn"); do printf "%s\n" ${arr[@]} | shuf | head -1; done) )

echo "[*] OUR ARRAY"
echo "[+] Array size: ${#second_arr[@]}"
b=0
for u in "${!second_arr[@]}"
do
        echo "index: $b | value: ${second_arr[$u]}"
        ((b=b+1))
done
i=0
for k in "${!second_arr[@]}"
do
        output_of_diff_path="${second_arr[$k]}.diff"
        output_of_koverage_path="output_of_koverage_path_${second_arr[$k]}.json"

        echo "[*] Index: $i"
        echo "[*] COMMIT: ${second_arr[$k]}"
        #printf "%s\n" ${second_arr[@]}

        echo "[*] RESETTING GIT HEAD"
        git reset --hard origin/master
        git checkout -f ${second_arr[$i]}

        echo "[*] CHECKING OUT TO ${second_arr[$i]}"
        git show > $output_of_diff$output_of_diff_path
        echo "[*] GIT SHOW: $output_of_diff$output_off_diff_path"
        #make defconfig
        #cp .config defconfig
        echo "[*] HEY HEY $output_of_diff$output_of_diff_path"
        rm -rf koverage_files

        echo "[!] THIS IS CONFIG FILE YOU SUPPLIED: $config_file"
        koverage -v --arch x86_64 --config $config_file --check-patch $output_of_diff$output_of_diff_path -o $output_of_koverage$output_of_koverage_path

        excluded_count=`cat $output_of_koverage$output_of_koverage_path | grep "EXCLUDED" | wc -l`
        sleep 5
        echo "[*] EXCLUDED COUNT: $excluded_count"
        if [ $excluded_count == 0 ]; then
                echo "[!] THERE'S NOTHING TO BE INCLUDED...PROCEEDING TO THE NEXT INTERVAL"
                #((i=i+1))
        else
                echo "[*] THE NUMBER OF EXCLUDEDS: $excluded_count"
                echo -e "${RED}[*] STARTING KLOCALIZER..."
                klocalizer -v -a x86_64 --repair $config_file --include-mutex $output_of_diff$output_of_diff_path --formulas ../formulacache --define CONFIG_KCOV --define CONFIG_DEBUG_INFO_DWARF4 --define CONFIG_KASAN --define CONFIG_KASAN_INLINE --define CONFIG_CONFIGFS_FS --define CONFIG_SECURITYFS --define CONFIG_CMDLINE_BOOL; rm -rf koverage_files/;
                echo -e "${NC}[*] MOVING REPAIRED CONFIG FILE TO THE DIRECTORY..."
                output_of_klocalizer="repaired_${second_arr[$k]}.config"
                FILE=0-x86_64.config
                if [ -f "$FILE" ]; then
                        echo "SATISFYING CONDITION IS FOUND"
                        mv 0-x86_64.config $output_of_klocalizer
        
        commit_hash=${second_arr[$k]}
        echo "[!] COMMIT HASH: ${commit_hash}"
        mv $output_of_klocalizer $output_of_repaired_koverage_path
        echo -e "[*] ${RED}STARTING KOVERAGE AGAIN TO CHECK FOR REPAIR..."
        
        # mov kov was here

        echo "[*] CHECK PATCH: $output_of_diff$output_of_diff_path"
        echo "[!] SANITY CHECK: $output_of_repaired_koverage_path$output_of_klocalizer"
        echo "[!] SANITY CHECK PATCH: $output_of_diff$output_of_diff_path"

        output_of_repaired_koverage_file="${second_arr[$k]}.diff.repaired.json"
        koverage -v --arch x86_64 --config $output_of_repaired_koverage_path$output_of_klocalizer --check-patch $output_of_diff$output_of_diff_path -o $output_of_repaired_koverage_file_path$output_of_repaired_koverage_file
        


        echo -e "${NC} [+] Moving REPAIRED KOVERAGE FILE..."
        #mv $output_of_repaired_koverage_file $output_of_repaired_koverage_file_path

        repaired_excluded_count=`cat ${output_of_repaired_koverage_file} | grep "EXCLUDED" | wc -l`
        #total_repaired_excluded+=$repaired_excluded_count
        echo "[*] REPAIRED EXCLUDED COUNT: $repaired_excluded_count"
        if [ $repaired_excluded_count == 0 ]; then
                
                echo "${NC}[+] WE REPAIRED THE FILE, GOING TO FUZZ IT"

                #echo "[+] Copying repaired config file to ${RED}${dir_linux_next}${NC}"
                #cp $output_of_repaired_koverage_path/$output_of_klocalizer $dir_linux_next
                
                cd $dir_linux_next

                echo "[+] Switching to linux-next directory: $dir_linux_next"

                echo "[+] Cleaning the linux-next repo"

                git clean -dfx


                echo "[+] Resetting the head to master"
                git reset --hard origin/master

                #echo "===============================CHECKING OUT TO THE COMMIT==============================="
                #git checkout -f ${second_arr[$k]}
                echo "[*] RUNNING DEFCONFIG"
                make defconfig
                echo "[*] RUNNING KVM GUEST CONFIG"
                make kvm_guest.config

                #cp .config "defconfig${second_arr[$k]}"
                cp $output_of_repaired_koverage_path/$output_of_klocalizer .config

                echo "CONFIG_CMDLINE=\"net.ifnames=0\"" >> .config
                #echo "CONFIG_DEBUG_INFO_BTF=n" >> .config

                echo "[+] RUNNING OLDDEFCONFIG ON THE REPAIRED CONFIG"
                make olddefconfig

                echo "[+] COMPILING THE KERNEL AGAIN WITH THE REPAIRED CONFIG"
                make -j`nproc`

                if ! make -j`nproc`; then
                        echo "[+] ERROR: Failed to compile the kernel for some reason."
                        exit 1
                fi


                mkdir /home/anon/opt/syzkaller/rep_${config_name}_${commit_hash}_$(date +'%m%d%Y')
                workdir_name="/home/anon/opt/syzkaller/rep_${config_name}_${commit_hash}_$(date +'%m%d%Y')"

                echo "[+] Creating new config file for repaired config"
                # create new config file for syzkaller config
                echo '{' > /home/anon/opt/syzkaller/my.cfg
                echo '  "target": "linux/amd64",' >> /home/anon/opt/syzkaller/my.cfg
                echo '  "http": "127.0.0.1:56741",' >> /home/anon/opt/syzkaller/my.cfg

                printf '        "workdir": "%s",\n' "$workdir_name" >> /home/anon/opt/syzkaller/my.cfg

                echo '  "kernel_obj": "/home/anon/linux-next",' >> /home/anon/opt/syzkaller/my.cfg
                echo '  "image": "/home/anon/Documents/opt/my-image/stretch.img",' >> /home/anon/opt/syzkaller/my.cfg
                echo '  "sshkey": "/home/anon/Documents/opt/my-image/stretch.id_rsa",' >> /home/anon/opt/syzkaller/my.cfg
                echo '  "syzkaller": "/home/anon/opt/syzkaller",' >> /home/anon/opt/syzkaller/my.cfg
                echo '  "procs": 8,' >> /home/anon/opt/syzkaller/my.cfg
                echo '  "type": "qemu",' >> /home/anon/opt/syzkaller/my.cfg
                echo '  "vm": {' >> /home/anon/opt/syzkaller/my.cfg
                echo '          "count": 8,' >> /home/anon/opt/syzkaller/my.cfg
                echo '          "kernel": "/home/anon/linux-next/arch/x86/boot/bzImage",' >> /home/anon/opt/syzkaller/my.cfg
                echo '          "cpu": 8,' >> /home/anon/opt/syzkaller/my.cfg
                echo '          "mem": 4098' >> /home/anon/opt/syzkaller/my.cfg
                echo '  }' >> /home/anon/opt/syzkaller/my.cfg
                echo '}' >> /home/anon/opt/syzkaller/my.cfg

                echo "[*] MOVING TO SYZKALLER DIRECTORY"
                cd $dir_syzkaller

                
                rep_syz_term_out=/home/anon/research/rep_syzkaller_terminal_output/rep_${config_name}_${commit_hash}_${current_date}
                
                echo "[+] Creating new tmux sesion"
                tmux new-session -d -s rep_${commit_hash} "timeout 12h /home/anon/opt/syzkaller/bin/syz-manager -config=my.cfg 2>&1 | tee ${rep_syz_term_out}; exec $SHELL"
                
                echo "[+] All steps completed successfully!"
                exit 1
                #echo "===============================RUNNING SYZKALLER==============================="
        fi
        #echo "TOTAL REPAIRED EXCLUDED COUNT: $total_repaired_excluded"
        fi
        fi

        echo "TETTESTET"
        ((i=i+1))
done
