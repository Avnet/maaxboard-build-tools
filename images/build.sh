#!/bin/bash

# this project absolute path
PRJ_PATH=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# top project absolute path
TOP_PATH=$(realpath $PRJ_PATH/..)

# binaries build prefix install path
PRFX_PATH=$PRJ_PATH/install

# binaries finally install path if needed
INST_PATH=/tftp

# config file path
CONF_FILE=$TOP_PATH/config.json

# shell script will exit once get command error
set -e
set -u

#+-------------------------+
#| Shell script functions  |
#+-------------------------+

function pr_error() {
    echo -e "\033[40;31m $1 \033[0m"
}

function pr_warn() {
    echo -e "\033[40;33m $1 \033[0m"
}

function pr_info() {
    echo -e "\033[40;32m $1 \033[0m"
}

# decompress a packet to destination path
function do_unpack()
{
    tarball=$1
    dstpath=`pwd`

    if [[ $# == 2 ]] ; then
        dstpath=$2
    fi

    pr_info "decompress $tarball => $dstpath"

    mkdir -p $dstpath
    case $tarball in
        *.tar.gz)
            tar -xzf $tarball -C $dstpath
            ;;

        *.tar.bz2)
            tar -xjf $tarball -C $dstpath
            ;;

        *.tar.xz)
            tar -xJf $tarball -C $dstpath
            ;;

        *.tar.zst)
            tar -I zstd -xf $tarball -C $dstpath
            ;;

        *.tar)
            tar -xf $tarball -C $dstpath
            ;;

        *.zip)
            unzip -qo $tarball -d $dstpath
            ;;

        *)
            pr_error "decompress Unsupport packet: $tarball"
            return 1;
            ;;
    esac
}

# parser configure file and export environment variable
function export_env()
{
    export BOARD=`jq -r ".bsp.board" $CONF_FILE | tr 'A-Z' 'a-z'`
    export BSP_VER=`jq -r ".bsp.version" $CONF_FILE`
    export GIT_URL=`jq -r ".bsp.giturl" $CONF_FILE | tr 'A-Z' 'a-z'`
    export BRANCH=`jq -r ".bsp.branch" $CONF_FILE`
    export DIS_VER=`jq -r ".system.version" $CONF_FILE | tr 'A-Z' 'a-z'`
    export IMAGE_SIZE=`jq -r ".system.imgsize" $CONF_FILE | tr 'A-Z' 'a-z'`
    export BOOT_SIZE=`jq -r ".system.bootsize" $CONF_FILE | tr 'A-Z' 'a-z'`

    if [[ ! -n $BRANCH ]] || [[ $BRANCH == null ]] ; then
        export BRANCH=maaxboard_$BSP_VER
    else
        export BSP_VER=$(echo $BRANCH | sed -E 's/.*(lf-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    fi

    export LOOP_DEV=`losetup  -f | cut -d/ -f3`
    export MNT_POINT=$PRJ_PATH/mnt

    export ROOTFS=rootfs-${DIS_VER}
    export UBOOT_BINPATH=$TOP_PATH/bootloader/install/
    export KERNEL_BINPATH=$TOP_PATH/kernel/install/
    export ROOTFS_BINPATH=$TOP_PATH/yocto/install/
    

    if [[ $BOARD = maaxboard ]] || [[ $BOARD = maaxboard-8ulp ]] || [[ $BOARD = maaxboard-mini ]] ; then
        export UBOOT_OFFSET_SECTOR=66
    elif [[ $BOARD = maaxboard-nano ]] || [[ $BOARD = maaxboard-osm93 ]] ; then
        export UBOOT_OFFSET_SECTOR=64
    fi
}

function do_fetch()
{
    cd $PRJ_PATH

    SRCS=$ROOTFS

    for src in $SRCS
    do
        if [ -d $ROOTFS/bin ] ; then
            pr_info "$src fetched already"
            continue
        fi

        for tarball in $ROOTFS_BINPATH/rootfs.tar.*
        do
            if [ -s $tarball ] ; then
                mkdir -p $ROOTFS
                do_unpack $tarball $ROOTFS
                break;
            fi
        done
    done
}

# System image layout map:
# +-------------------+--------------------+----------------------+
# | Raw Part(10MB)    | FAT32 Part2(100MB) | EXT4 Part3(All left) |
# +-------------------+--------------------+----------------------+
# | U-boot on #64     |   Kernel and DTB   |   Root file system   |
# +-------------------+--------------------+----------------------+

function build_image()
{
    export IMAGE_NAME=$BOARD-$DIS_VER.img

    # Uboot size set be 10MB and deployed in 64th sector on eMMC/TFCard
    UBOOT_SIZE=10

    mkdir -p $MNT_POINT

    pr_info "start generate ${IMAGE_SIZE}MB empty system image"
    dd if=/dev/zero of=${IMAGE_NAME} bs=1024k count=${IMAGE_SIZE} conv=sync
    chmod a+x ${IMAGE_NAME}

    pr_info "start partition system image"
    fat_start=$UBOOT_SIZE
    fat_end=`expr $UBOOT_SIZE + $BOOT_SIZE`
    parted ${IMAGE_NAME} mklabel msdos
    parted ${IMAGE_NAME} mkpart primary fat32 ${fat_start}M ${fat_end}M
    parted ${IMAGE_NAME} mkpart primary ext4 ${fat_end}M 100%
    sync

    pr_info "losetup system image on $LOOP_DEV"
    losetup /dev/${LOOP_DEV}  ${IMAGE_NAME}
    kpartx -av /dev/${LOOP_DEV}

    pr_info "start format system image"
    mkfs.vfat /dev/mapper/${LOOP_DEV}p1
    mkfs.ext4 /dev/mapper/${LOOP_DEV}p2
    sync

    pr_info "start install u-boot image"
    dd if=$UBOOT_BINPATH/u-boot-${BOARD}.imx of=${IMAGE_NAME} bs=512 seek=${UBOOT_OFFSET_SECTOR} conv=notrunc,sync

    pr_info "start install linux kernel images"
    mount -t vfat /dev/mapper/${LOOP_DEV}p1 ${MNT_POINT}
    cp -rf $KERNEL_BINPATH/Image       ${MNT_POINT}/
    cp -rf $KERNEL_BINPATH/${BOARD}.dtb ${MNT_POINT}/
    cp -rf $KERNEL_BINPATH/overlays/    ${MNT_POINT}/

    if [ -f $ROOTFS/boot/readme.txt ] ; then
        cp $ROOTFS/boot/readme.txt ${MNT_POINT}/
    fi

    if [ -f $ROOTFS/boot/uEnv.txt ] ; then
        cp $ROOTFS/boot/uEnv.txt ${MNT_POINT}/
    elif [ -f $PRJ_PATH/conf/$BOARD/uEnv.txt ] ; then
        cp $PRJ_PATH/conf/$BOARD/uEnv.txt ${MNT_POINT}/
    fi

    sync && umount ${MNT_POINT}

    pr_info "update drivers in root filesystem"
    rm -rf $ROOTFS/lib/modules/
    mkdir -p $ROOTFS/lib/modules/
    cp -rf $KERNEL_BINPATH/lib/modules/[0-9]*\.[0-9]*\.[0-9]* $ROOTFS/lib/modules/

    if [ -f $PRJ_PATH/conf/$BOARD/asound.conf ] ; then
        cp $PRJ_PATH/conf/$BOARD/asound.conf $ROOTFS/etc/asound.conf
    fi

    if [ -f $PRJ_PATH/conf/$BOARD/asound.state ] ; then
        cp $PRJ_PATH/conf/$BOARD/asound.state $ROOTFS/var/lib/alsa/asound.state
    fi

    pr_info "start install root filesystem"
    mount -t ext4 /dev/mapper/${LOOP_DEV}p2 ${MNT_POINT}
    cp -af $ROOTFS/* ${MNT_POINT}
    sync && umount ${MNT_POINT}

    pr_warn "Build $BOARD-$BSP_VER-$DIS_VER system image done"
}

function exit_handler()
{
    pr_warn "Shell script exit now, do some clean work\n"
    set +e

    if mountpoint ${MNT_POINT} > /dev/null 2>&1 ; then
        pr_info "umount ${MNT_POINT}"
        umount ${MNT_POINT} > /dev/null 2>&1
    fi

    rm -rf ${MNT_POINT}

    if [ -e /dev/mapper/${LOOP_DEV}p1 ] ; then
        pr_info "kpartx -dv /dev/${LOOP_DEV}"
        kpartx -dv /dev/${LOOP_DEV}
    fi

    losetup -a | grep "${LOOP_DEV}" > /dev/null 2>&1
    if [ $? == 0 ]  ; then
        pr_info "losetup -d /dev/${LOOP_DEV}"
        losetup -d /dev/${LOOP_DEV}
    fi
}

function do_build()
{
    cd $PRJ_PATH

    build_image
}

function do_install()
{
    cd $PRJ_PATH

    mkdir -p $PRFX_PATH
    cp $UBOOT_BINPATH/u-boot-${BOARD}.imx $PRFX_PATH
    mv $IMAGE_NAME $PRFX_PATH

    if [[ -n "$INST_PATH" && -w $INST_PATH ]] ; then
        pr_info "install bootloader and system image to '$INST_PATH'"
        cp $PRFX_PATH/u-boot-${BOARD}.imx $INST_PATH
        cp $PRFX_PATH/$IMAGE_NAME $INST_PATH
    fi
}

function do_clean()
{
    for d in rootfs-*
    do
        rm -rf $PRJ_PATH/$d
    done

    rm -f *.img
}

#+-------------------------+
#| Shell script body entry |
#+-------------------------+

if [ `id -u` != 0 ] ; then
    pr_error "ERROR: This shell script must run as root"
    exit;
fi

cd $PRJ_PATH

export_env

if [[ $# == 1 && $1 == -c ]] ;then
    pr_warn "start clean system image"
    do_clean
    exit;
fi

pr_warn "Build $BOARD-$BSP_VER-$DIS_VER system image"

trap 'exit_handler' EXIT

do_fetch

do_build

do_install

