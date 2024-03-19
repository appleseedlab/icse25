#!/bin/bash

# example: bash /data1/paul/kmax/scripts/krepair_syzkaller_evaluation/paper/run_evaluate_syzkaller_config.sh linux/ c07ba878ca199a6089cdb323bf526adbeeb4201f x86_64 formulacache outdir_with_build_j/c07ba878ca199a6089cdb323bf526adbeeb4201f ~/Documents/syzkaller

set -x

# used to find other scripts called
script_dir=$(dirname $(realpath $0))

krepaironly=true
all=

if [ "$#" -lt 6 ]; then
	echo "Illegal number of parameters"
	exit -1
fi

linuxsrclone=${1}
linuxsrclone=$(realpath ${linuxsrclone})
commit=${2}
arch=${3}
formulacache=${4}
outdir=${5}

syzkallersrc=${6}
syzkallersrc=$(realpath ${syzkallersrc})

if [ -d $outdir ]; then
	echo "ERROR: output directory already exists"
	exit 1
else
	mkdir -p $outdir
fi
outdir=$(realpath $outdir)

build_flags=$7

patch=${outdir}/commit.patch

(
	cd ${linuxsrclone}
	git checkout -f $commit
)
(
	cd ${linuxsrclone}
	git clean -dfx
)
(
	cd ${linuxsrclone}
	git show >${patch}
)

# syzkaller config
config_outdir=${outdir}/syzkaller_config
mkdir ${config_outdir}

config=${config_outdir}/config
#(cd ${linuxsrclone}; KCONFIG_CONFIG=${config} make.cross ARCH=${arch} defconfig)
echo "[+] Going to execute syz-kconf now..."
(
	cd ${syzkallersrc}
	echo "[+] Current path: $PWD... Executing syz-kconf now:"

	# modify main.yml to use commit id you specified to checkout the kernel source when building the config with syz-kconf
	syzkconf_config_path=${syzkallersrc}/dashboard/config/linux/main.yml
	# yq -i '.kernel.tag = "$commit"' $sykconf_config_path

	# change value of the tag key of the main.yml file without yq
	linux_yml_path=${syzkallersrc}/dashboard/config/linux/bits/linux-next.yml
	awk -v commit="$commit" '
  BEGIN {OFS=FS=": "}
  /^kernel:$/ {seen=1; print; next}
  seen && /^  tag:/ { $2=" "commit; seen=0 }
  {print}
  ' $linux_yml_path >temp.yml && mv temp.yml $linux_yml_path

	echo "[+] tag value after modifying it:"
	grep 'tag:' $linux_yml_path | awk '{print $2}'

	output=$(./tools/syz-kconf/syz-kconf -config ${syzkconf_config_path} -instance upstream-apparmor-kasan -sourcedir ${linuxsrclone} 2>&1)
	echo "$output" | grep "saved config before olddefconfig to" >/dev/null
	if [ $? -eq 0 ]; then
		mv ${syzkallersrc}/dashboard/config/linux/upstream-apparmor-kasan.config.tmp ${config}
	else
		mv ${syzkallersrc}/dashboard/config/linux/upstream-apparmor-kasan.config ${config}
	fi
)

results=${config_outdir}/results

bash ${script_dir}/evaluate_syzkaller_config.sh ${linuxsrclone} ${patch} ${config} ${arch} ${formulacache} ${results}
