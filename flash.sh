#!/usr/bin/env sh

set -exu

DISK=/dev/sda
PARTITION=/dev/sda1
MOUNTPOINT=usbmnt
ARTIFACT=filesystem.squashfs

if ! [ -x "$(command -v extlinux)" ]; then
    apt install -y extlinux
fi
if ! [ -x "$(command -v parted)" ]; then
    apt install -y parted
fi

parted --script $DISK \
    mklabel msdos \
    mkpart primary ext2 1MiB 2048MiB \
    set 1 boot on
sleep 1
mkfs.ext2 -F $PARTITION
mkdir $MOUNTPOINT
dd bs=440 count=1 conv=notrunc if=mbr.bin of=$DISK
mount $PARTITION $MOUNTPOINT
mkdir -p $MOUNTPOINT/boot
extlinux -i $MOUNTPOINT/boot
cp extlinux.conf $MOUNTPOINT/boot
cp build/boot/vmlinuz-* $MOUNTPOINT/vmlinuz
cp build/boot/initrd.img-* $MOUNTPOINT/initrd
mkdir -p $MOUNTPOINT/live
cp $ARTIFACT $MOUNTPOINT/live/
umount $MOUNTPOINT
rm -rf $MOUNTPOINT
