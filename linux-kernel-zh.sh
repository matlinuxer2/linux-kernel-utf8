#!/usr/bin/env bash
#
# Author: Chun-Yu Lee (Mat) <matlinuxer2@gmail.com>
# 	, wayling <waylingII@gmail.com>
#

ROOT="$( readlink -f $( dirname $(echo $0)) )" 

KERNEL_VERSION_TAG="v2.6.37"
KERNEL_SOURCE_GIT="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux-2.6.git"
KERNEL_SOURCE_GIT_DIR="$ROOT/linux-2.6"

BUSYBOX_VERSION_TAG="1_17_2"
BUSYBOX_SOURCE_GIT="git://busybox.net/busybox.git"
BUSYBOX_SOURCE_GIT_DIR="$ROOT/busybox"

RESULT_DIR="$ROOT/image"
INITRAMFS_DIR="$ROOT/image/_install"

ZH_PATCH_PREFIX="http://zdbr.net.cn/download/"
ZH_PATCH1="utf8-kernel-2.6.37-core-1.patch.bz2"
ZH_PATCH2="utf8-kernel-2.6-fonts-3.patch.bz2"

get_patch() {
	# TODO: would be better if we got md5sum as existance checing.

	wget --continue $ZH_PATCH_PREFIX/$ZH_PATCH1
	wget --continue $ZH_PATCH_PREFIX/$ZH_PATCH2

	for file in `ls *.bz2`
	do 
		bzip2 -d $file
	done
}

clean_file() {
	test -f "$1" && rm -vf "$1"
}

patch_busybox_config(){
	local CONFIG=$(readlink -f $1)

        sed -i -e '$a #' $CONFIG
        sed -i -e '$a # Automatic script customization sections' $CONFIG
        sed -i -e '$a #' $CONFIG

	sed -i -e '/^# CONFIG_STATIC is not set/d' $CONFIG 
	sed -i -e '$a CONFIG_STATIC=y' $CONFIG
}

build_busybox () {
	test -d $KERNEL_SOURCE_GIT_DIR || git clone $KERNEL_SOURCE_GIT
	test -d $BUSYBOX_SOURCE_GIT_DIR || git clone $BUSYBOX_SOURCE_GIT
	test -d $RESULT_DIR || mkdir -p $RESULT_DIR

	pushd . ; cd $BUSYBOX_SOURCE_GIT_DIR
		git reset && git checkout $BUSYBOX_VERSION_TAG 
		git checkout -- .

		make ARCH=x86 defconfig
		patch_busybox_config ./.config

		make -j3
		make install
		cp -vR $BUSYBOX_SOURCE_GIT_DIR/_install $RESULT_DIR
	popd
}

setup_initrd(){
	pushd . ; cd $INITRAMFS_DIR;
		test -d proc || mkdir proc
		test -d sys || mkdir proc
		test -d dev || mkdir proc

		pushd . ; cd dev
			test -f console || sudo mknod console c 5 1
		popd

		cp -v $ROOT/init.sh  $RESULT_DIR/_install/init
	popd
}

patch_kernel_config(){
	local CONFIG=$(readlink -f $1)

	# user comment
        sed -i -e '$a #' $CONFIG
        sed -i -e '$a # Automatic script customization sections' $CONFIG
        sed -i -e '$a #' $CONFIG

	# turn on framebuffer built-in support. !IMPORTANT
	sed -i -e '/^CONFIG_FB_VESA/d' $CONFIG 
        sed -i -e '$a CONFIG_FB_VESA=y' $CONFIG
	sed -i -e '/^CONFIG_FB_BOOT_VESA_SUPPORT/d' $CONFIG 
        sed -i -e '$a CONFIG_FB_BOOT_VESA_SUPPORT=y' $CONFIG
        sed -i -e '$a CONFIG_FB_VGA16=y' $CONFIG

	# needed by initramfs, point to the initrd directory !IMPORTANT
	sed -i -e '/^CONFIG_INITRAMFS_SOURCE/d' $CONFIG
        sed -i -e '$a CONFIG_INITRAMFS_SOURCE="BUSYBOX_INITRAMFS_DIR"' $CONFIG
        sed -i -e "s/BUSYBOX_INITRAMFS_DIR/${INITRAMFS_DIR//\//\\/}/g" $CONFIG

	# needed by initramfs
	sed -i -e '$a CONFIG_INITRAMFS_ROOT_UID=0' $CONFIG
	sed -i -e '$a CONFIG_INITRAMFS_ROOT_GID=0' $CONFIG

	# needed by initramfs
	sed -i -e '$a CONFIG_INITRAMFS_COMPRESSION_NONE=y' $CONFIG
	sed -i -e '$a # CONFIG_INITRAMFS_COMPRESSION_GZIP is not set' $CONFIG
	sed -i -e '$a # CONFIG_INITRAMFS_COMPRESSION_BZIP2 is not set' $CONFIG
	sed -i -e '$a # CONFIG_INITRAMFS_COMPRESSION_LZMA is not set' $CONFIG
	sed -i -e '$a # CONFIG_INITRAMFS_COMPRESSION_LZO is not set' $CONFIG

	# enable /proc/config.gz, help to check kernel config on the fly
	sed -i -e '/^CONFIG_IKCONFIG/d' $CONFIG 
	sed -i -e '$a CONFIG_IKCONFIG=y' $CONFIG
	sed -i -e '$a CONFIG_IKCONFIG_PROC=y' $CONFIG
}

build_kernel () {
	test -d $KERNEL_SOURCE_GIT_DIR || git clone $KERNEL_SOURCE_GIT
	test -d $BUSYBOX_SOURCE_GIT_DIR || git clone $BUSYBOX_SOURCE_GIT
	test -d $RESULT_DIR || mkdir -p $RESULT_DIR
	
	pushd . ; cd $KERNEL_SOURCE_GIT_DIR
		git fetch
		git reset; git checkout $KERNEL_VERSION_TAG 
		git checkout -- .

		clean_file drivers/video/console/fonts_utf8.h # reset file

		patch -N -d . -p1 < $ROOT/${ZH_PATCH1%.bz2}
		patch -N -d . -p1 < $ROOT/${ZH_PATCH2%.bz2}

		make ARCH=x86 i386_defconfig
		patch_kernel_config ./.config

		make -j3 bzImage
		cp -v $KERNEL_SOURCE_GIT_DIR/arch/x86/boot/bzImage $RESULT_DIR/
	popd
}

launch_image(){
	pushd . ; cd $RESULT_DIR
	qemu -kernel bzImage -append "vga=0x314 root=/dev/ram0" 
	popd
}


#
# Main routine 
#
echo "The top directory: (all relative files will be stored here)"
echo "    $ROOT"
echo ""

echo " 1 => Run all ( fetch,build busybox, build kernel, and launch qeme )" 
echo " 2 => build kernel only"
echo " 3 => launch qemu only"
read -p "Select action: [1/2/3] (default:1)" WHICH_ACTION
echo "Starting..."

if [ "x$WHICH_ACTION" = "x1" -o "x$WHICH_ACTION" = "x" ]; then
	echo "Run all..."
	get_patch          
	build_busybox      
	setup_initrd       
	build_kernel       
	launch_image       
elif [ "x$WHICH_ACTION" = "x2" ]; then
	echo "build kernel only..."
	setup_initrd       
	build_kernel       
elif [ "x$WHICH_ACTION" = "x3" ]; then
	echo "launching qemu..."
	launch_image      
else
	echo "no such options"
fi
