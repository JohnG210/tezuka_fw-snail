#!/bin/sh
set -e

COMMON_DIR=$(dirname $0)
BIN_DIR=$1
# Args from BR2_ROOTFS_POST_IMAGE_SCRIPT_ARG in board config file
BOARD_DIR="$2"
DTB_NAME="$3"
dfu_suffix=$HOST_DIR/bin/dfu-suffix

DEVICE_VID=0x0456
DEVICE_PID=0xb673

cp $BOARD_DIR/plutomaia.its $BIN_DIR/plutomaia.its

echo "# entering $BIN_DIR for the next command"
(cd $BIN_DIR && mkimage -f plutomaia.its pluto.itb)

echo "generating the pluto.frm"
md5sum $BIN_DIR/pluto.itb | cut -d ' ' -f 1 > $BIN_DIR/pluto.md5
cat $BIN_DIR/pluto.itb $BIN_DIR/pluto.md5 > $BIN_DIR/pluto.frm

echo "generating pluto.dfu"
cp $BIN_DIR/pluto.itb $BIN_DIR/plutocopy.itb
$dfu_suffix -a $BIN_DIR/pluto.itb -v $DEVICE_VID -p $DEVICE_PID
mv $BIN_DIR/pluto.itb $BIN_DIR/pluto.dfu

echo "generating the boot.img"
cp $BOARD_DIR/bitstream/fsbl.elf $BIN_DIR
# Use pre-built U-Boot if available (buildroot-compiled one is broken for plutoplus)
if [ -f "$BOARD_DIR/bitstream/u-boot.elf" ]; then
	echo "using pre-built u-boot.elf from $BOARD_DIR/bitstream/"
	cp $BOARD_DIR/bitstream/u-boot.elf $BIN_DIR/u-boot.elf
else
	cp $BIN_DIR/u-boot $BIN_DIR/u-boot.elf
fi
echo "img : {[bootloader] $BIN_DIR/fsbl.elf $BIN_DIR/u-boot.elf}" > $BIN_DIR/boot.bif
bootgen -image $BIN_DIR/boot.bif -w -o i $BIN_DIR/boot.img

echo "generating the boot.frm"
cat $BIN_DIR/boot.img $BIN_DIR/uboot-env.bin $COMMON_DIR/target_mtd_info.key | \
	tee $BIN_DIR/boot.frm | md5sum | cut -d ' ' -f1 | tee -a $BIN_DIR/boot.frm

echo "generating boot.dfu"
cp $BIN_DIR/boot.img $BIN_DIR/boot.bin.tmp
$dfu_suffix -a $BIN_DIR/boot.bin.tmp -v $DEVICE_VID -p $DEVICE_PID
mv $BIN_DIR/boot.bin.tmp $BIN_DIR/boot.dfu

echo "generating uboot-env.dfu"
cp $BIN_DIR/uboot-env.bin $BIN_DIR/uboot-env.bin.tmp
$dfu_suffix -a $BIN_DIR/uboot-env.bin.tmp -v $DEVICE_VID -p $DEVICE_PID
mv $BIN_DIR/uboot-env.bin.tmp $BIN_DIR/uboot-env.dfu

echo "generating sd"
SDIMGDIR=$BIN_DIR/sdimg
mkdir -p $SDIMGDIR

# SD BOOT.bin: FSBL + bitstream + U-Boot
echo "img : {[bootloader] $BIN_DIR/fsbl.elf $BIN_DIR/system_top.bit $BIN_DIR/u-boot.elf}" > $SDIMGDIR/boot.bif
bootgen -image $SDIMGDIR/boot.bif -w -o i $SDIMGDIR/BOOT.bin

# Convert bitstream to .bin format for U-Boot fpga load command
echo "all: { $BIN_DIR/system_top.bit }" > $SDIMGDIR/bit.bif
bootgen -image $SDIMGDIR/bit.bif -arch zynq -process_bitstream bin -w -o $SDIMGDIR/system_top.bit.bin

if [ -e $BOARD_DIR/bitstream/overclock/ ]; then
    mkdir -p $SDIMGDIR/overclock
    for filename in $BOARD_DIR/bitstream/overclock/*.elf ; do
        echo "img : {[bootloader] $filename $BIN_DIR/u-boot.elf}" > $SDIMGDIR/boot.bif
        NAME=`basename -- "$filename" .elf`
        bootgen -image $SDIMGDIR/boot.bif -w -o i $SDIMGDIR/overclock/"BOOT_"$NAME
    done
fi

rm $SDIMGDIR/boot.bif $SDIMGDIR/bit.bif
mkimage -A arm -T ramdisk -C gzip -d $BIN_DIR/rootfs.cpio.gz $SDIMGDIR/uramdisk.image.gz
mkimage -A arm -O linux -T kernel -C none -a 0x2080000 -e 2080000 -n "Linux kernel" -d $BIN_DIR/zImage $SDIMGDIR/uImage
cp $BIN_DIR/$DTB_NAME $SDIMGDIR/devicetree.dtb
cp $COMMON_DIR/uboot-env.txt $SDIMGDIR/uEnv.txt

cd $BIN_DIR && zip -r tezuka.zip boot.dfu boot.frm pluto.frm pluto.dfu sdimg/*
