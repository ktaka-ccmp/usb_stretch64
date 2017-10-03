#!/bin/bash

removable(){
if  (readlink -f /sys/block/${1}/device|egrep -q usb) ; then
	dev=/dev/${1}
else
	echo "${1} is not a USB device !"
	exit 1
fi
}

case "$1" in
        sda|sdb|sdc)
        removable $1
        ;;

        *)
        echo "Usage: $0 [sda,sdb,sdc]"
        exit 1
        ;;

esac

echo  "About to initialize  $dev .. Are you sure ? [y/N]"
read ans
if [ "$ans" != "y" ]; then
	echo Aborting...
	exit 1
fi

sfdisk $dev << EOF
,,L
EOF

partprobe

mkfs.ext4 -F -L usbdebian ${dev}1

#grub-mkimage -o ./image/boot/grub/core.img  ext2 part_msdos biosdisk -O i386-pc
make update

mount -L usbdebian ./mnt
grub-install --boot-directory=./mnt/boot/ ${dev}
umount ./mnt

sfdisk -A $dev 1


