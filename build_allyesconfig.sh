linuxsrc=$1
kernel_image_save_path=$2

set -x

(
	cd $linuxsrc
	git clean -dfx
)
(
	cd $linuxsrc
	git checkout v6.7
)
(
	cd $linuxsrc
	make allyesconfig
)
(
	cd $linuxsrc
	make -j$(nproc)
)

cp $linuxsrc/arch/x86/boot/bzImage $kernel_image_save_path
