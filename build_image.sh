#!/bin/bash
#
# Reference: <<i.MX Linux® User's Guide.pdf>>
#
# SD Card partition layout:   1 Sector= 512B
#
# +-------------------------------+-----------------------+---------------------------------+
# |         Start  Address        |         Size          |           Usage                 |
# +-------------------------------+-----------------------+---------------------------------+
# |             0x0               |   32 sectors(16K)     |  Reserved for partition table   |
# +-------------------------------+-----------------------+---------------------------------+
# |    66 sector(33K, 0x8400)     |  20414 sectors(9M+)   |        i.MX8 u-boot image       |
# +-------------------------------+-----------------------+---------------------------------+
# |  20480 sector(10M, 0xa00000)  | 204800 sectors(100MB) |      FAT32 Boot partition       |
# +-------------------------------+-----------------------+---------------------------------+
# | 225280 sector(110M,0x6e00000) |    Remaining Space    |     EXT4 filesystem for rootfs  |
# +-------------------------------+-----------------------+---------------------------------+
#

# This script must run as root, it doesn't have the export environment now.
SCRIPT_PATH=`realpath ${BASH_SOURCE[0]}`
export TOOLS_PATH=`dirname $SCRIPT_PATH`
export PJ_PATH=`realpath ${TOOLS_PATH}/../`
export BD_PATH=$PJ_PATH/work
export FS_PATH=$BD_PATH/rootfs
export IMG_PATH=$BD_PATH/images
export TMP_PATH=$BD_PATH/tmp

export CONF_FILE=${TOOLS_PATH}/config.json
export BOARD=`jq -r ".common.board" $CONF_FILE`
IMAGE_NAME=`jq -r ".image.name" $CONF_FILE`
export IMAGE_NAME=`eval echo $IMAGE_NAME`
export IMAGE_SIZE=`jq -r ".image.size" $CONF_FILE`

. $TOOLS_PATH/func_tools.sh

pr_warn "start generate system image"
set -e

if [ `id -u` != 0 ] ; then
    pr_error "This script must run as root privilege"
    exit;
fi

loop_dev=`losetup  -f | cut -d/ -f3`
mnt_point=$IMG_PATH/mnt
mkdir -p $mnt_point

function exit_handler()
{
    pr_warn "Shell script exit now, do some clean work\n"
    set +e

    if mountpoint $mnt_point > /dev/null 2>&1 ; then
        echo "umount ${mnt_point}"
        umount ${mnt_point} > /dev/null 2>&1
    fi

    rm -rf ${mnt_point}

    if [ -e /dev/mapper/${loop_dev}p1 ] ; then
        echo "kpartx -dv /dev/${loop_dev}"
        kpartx -dv /dev/${loop_dev}
    fi

    losetup -a | grep "${loop_dev}" > /dev/null 2>&1
    if [ $? == 0 ]  ; then
        echo "losetup -d /dev/${loop_dev}"
        losetup -d /dev/${loop_dev}
    fi
}
trap 'exit_handler' EXIT

function generate_image()
{
    # FAT32 boot partition start/end address in MB, total 100MB here
    fat_start=10
    fat_end=110

    pr_info "Generate system image "

    dd if=/dev/zero of=${IMAGE_NAME} bs=1024k count=${IMAGE_SIZE}  && sync
    chmod a+x ${IMAGE_NAME}

    pr_info "Partition system image"

    parted ${IMAGE_NAME} mklabel msdos
    parted ${IMAGE_NAME} mkpart primary fat32 ${fat_start}M ${fat_end}M
    parted ${IMAGE_NAME} mkpart primary ext4 ${fat_end}M 100%

    sync
}


function format_partition()
{
    pr_info "losetup image on $loop_dev"

    losetup /dev/${loop_dev}  ${IMAGE_NAME}
    kpartx -av /dev/${loop_dev}

    pr_info "format system image partition"
    mkfs.vfat /dev/mapper/${loop_dev}p1
    mkfs.ext4 /dev/mapper/${loop_dev}p2
    sync
}


function install_sysimg()
{
    pr_info "install u-boot image"
    sudo dd if=$TMP_PATH/u-boot-${BOARD}.imx of=${IMAGE_NAME} bs=512 seek=66 conv=notrunc,sync

    pr_info "install linux kernel image"

    mount -t vfat /dev/mapper/${loop_dev}p1 ${mnt_point}

    cp -rf $TMP_PATH/boot/* ${mnt_point}

    sync
    umount ${mnt_point}
}


function install_rootfs()
{
    pr_info "install root filesystem ${FS_PATH}/rootfs "

    mount -t ext4 /dev/mapper/${loop_dev}p2 ${mnt_point}
    cp -af ${FS_PATH}/rootfs/* ${mnt_point}
    chown -R root.root ${mnt_point}/*

    sync
    umount ${mnt_point}
}

function do_build()
{
    generate_image
    format_partition
    install_sysimg
    install_rootfs

    pr_info "generate system image done\n"

    ls && echo ""
}

function do_clean()
{
    cd $IMG_PATH

    for f in `ls`
    do
        if [[ $f != build.sh ]] ; then
            rm -rf $f
        fi
    done
}

if [[ $# == 1 && $1 == -c ]] ;then
    do_clean
    exit;
fi

do_build
