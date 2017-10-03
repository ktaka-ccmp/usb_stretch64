
TOP_DIR=${PWD}
IMG_DIR=${TOP_DIR}/Build/image/
SRC_DIR=${TOP_DIR}/Build/src/
FILE_DIR=${TOP_DIR}/file/

KVER=4.13.4
KVER_MINOR=-64usb01

BUSYBOX_URI=http://busybox.net/downloads/busybox-1.27.2.tar.bz2
BUSYBOX_FILE=$(notdir ${BUSYBOX_URI})
BUSYBOX=$(BUSYBOX_FILE:.tar.bz2=)
 
KERN_DIR=${SRC_DIR}/linux-${KVER}

default: 
	@sleep 0.3
	@echo -e "Usage: make target "
	@echo -e " Available Targets "
	@echo -e "\t all		: Make all files"
	@echo -e "\t "
	@echo -e "\t kernel		: Compile kernel"
	@echo -e "\t initrd.img			: Create initrd image"
	@echo -e "\t rootfs.tgz			: Create rootfs archive"
	@echo -e "\t "
	@echo -e " Other Targets "
	@echo -e "\t update:"
	@echo -e "\t	 		Sync ./image to ./mnt"
	@echo -e "\t 			(This assumes usb partition is labeled with \"usbdebian\".)"


.PHONY: default

all: 
	make initrd.img
	make rootfs.tgz
	make kernel

.PHONY: all kernel  
.PHONY: install install-kernel install-rootfs 

.PHONY: update
update:
	mkdir -p ${TOP_DIR}/mnt
	mount -L usbdebian ${TOP_DIR}/mnt
	if mountpoint ${TOP_DIR}/mnt > /dev/null  ; then \
		CONF=$(shell /bin/readlink ${TOP_DIR}/mnt/config.tgz);\
		rsync  -arv ${IMG_DIR}/ ${TOP_DIR}/mnt/ ; \
		if [ "$$CONF" != "" ]; then (cd ${TOP_DIR}/mnt; ln -sf $$CONF config.tgz ) ; fi ;\
		ls -la ${TOP_DIR}/mnt ;\
		sync ;\
	fi
	umount ${TOP_DIR}/mnt

.PHONY: ${SRC_DIR}
${SRCE_DIR}:
	mkdir -p $@

.PHONY: ${IMAGE_DIR}
${IMAGE_DIR}:
	if [ ! -d $@ ] ; then mkdir -p $@ && rsync -av ${FILE_DIR}/image/ $@  ; fi

.PHONY: initrd.img
initrd.img: ${SRC_DIR}/initrd-usb-cpio ${IMAGE_DIR}
	(cd $< ;find . | cpio -o -H newc | gzip -9 -n > ${IMG_DIR}/boot/initrd.img)

.PHONY: ${SRC_DIR}/initrd-usb-cpio
${SRC_DIR}/initrd-usb-cpio: ${SRC_DIR}/${BUSYBOX}/_install 
	mkdir -p $@
	rsync -a --delete $</ $@/
	mkdir -p $@/{sysroot,proc,sys,dev}
	cp ${FILE_DIR}/init $@

.PHONY: ${SRC_DIR}/${BUSYBOX}/_install
${SRC_DIR}/${BUSYBOX}/_install: ${SRC_DIR}
	if [ ! -d ${SRC_DIR}/${BUSYBOX} ]; then \
	wget -c ${BUSYBOX_URI} ; \
	tar xf ${BUSYBOX_FILE} -C ${SRC_DIR}; rm ${BUSYBOX_FILE} ; fi
	cp ${FILE_DIR}/dot.config.busybox ${SRC_DIR}/${BUSYBOX}/.config
	(cd ${SRC_DIR}/${BUSYBOX} ; \
	make menuconfig ; \
	time make -j 20 install )
	egrep  "CONF|^$$" ${SRC_DIR}/${BUSYBOX}/.config > ${FILE_DIR}/dot.config.busybox 

.PHONY: rootfs.tgz
rootfs.tgz: ${SRC_DIR}/rootfs_${DEBIAN} ${IMG_DIR}
	(cd $< ; tar cf - .)|gzip > ${IMG_DIR}/rootfs.tgz.0
	(cd $< ; tar cf - etc )|gzip > ${IMG_DIR}/config.tgz.0

.PHONY: ${SRC_DIR}/rootfs_${DEBIAN}
${SRC_DIR}/rootfs_${DEBIAN}:
	if [ -d $@ ]; then rm -rf ${SRC_DIR}/rootfs_${DEBIAN} && mkdir -p $@ ; fi
	debootstrap --include=openssh-server,openssh-client,rsync,pciutils,\
	tcpdump,strace,libpam-systemd,ca-certificates,telnet,curl,ncurses-term,\
	tree,psmisc,\
	sudo,aptitude,ca-certificates,apt-transport-https,\
	less,screen,ethtool,sysstat,tzdata,libpam0g,\
	sudo \
	stretch $@/ http://deb.debian.org/debian ; \
	echo "root:usb" | chpasswd --root ${TOP_DIR}/mnt/tmp/ ; \
	apt-get -o RootDir=$@/ clean ;\

kernel: ${SRC_DIR}/linux-${KVER}/.config
	ARCH=x86_64 nice -n 10 make -C ${SRC_DIR}/linux-${KVER} -j20
	ARCH=x86_64 make -C ${SRC_DIR}/linux-${KVER} modules_install INSTALL_MOD_PATH=${SRC_DIR} ; \
	(cd ${SRC_DIR}; tar cf - lib/modules/${KVER}${KVER_MINOR} | gzip > ${IMG_DIR}/modules.tgz ;\
	rm -rf lib )
	ARCH=x86_64 make -C ${SRC_DIR}/linux-${KVER} install INSTALL_PATH=${IMG_DIR}/boot/
	(cd ${SRC_DIR}/linux-${KVER}/; tar zcf ${FILE_DIR}/kernel.config.tgz .config; touch .config)

${SRC_DIR}/linux-${KVER}/.config: ${FILE_DIR}/kernel.config.tgz
	if [ ! -d ${SRC_DIR}/linux-${KVER} ]; then \
	(cd kernel/ ; wget http://www.kernel.org/pub/linux/kernel/v4.x/linux-${KVER}.tar.xz; \
	tar -xf linux-${KVER}.tar.xz; ) ; fi
	(cd ${SRC_DIR}/linux-${KVER}/; tar -zxvf ${FILE_DIR}/kernel.config.tgz; \
	cp -v .config .config.tmp ;\
	sed -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"${KVER_MINOR}\"/g' .config.tmp > .config ;\
	rm .config.tmp )
	ARCH=x86_64 make -C ${SRC_DIR}/linux-${KVER} menuconfig
	(cd ${SRC_DIR}/linux-${KVER}/; cp -v  .config .config.tmp ;\
	sed -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"${KVER_MINOR}\"/g' .config.tmp > .config ;\
	rm .config.tmp )
	(cd ${SRC_DIR}/linux-${KVER}/; tar zcf ${FILE_DIR}/kernel.config.tgz .config; touch .config)


.PHONY: clean
clean:
	rm -rf ${TOP_DIR}/Build

