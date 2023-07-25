#!/bin/bash

# this project absolute path
PRJ_PATH=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# top project absolute path
TOP_PATH=$(realpath $PRJ_PATH/..)

# binaries install path
INST_PATH=$PRJ_PATH/install

# config file path
CONF_FILE=$TOP_PATH/config.json

# shell script will exit once get command error
set -e

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

# select firmware version by BSP version
function export_fmver()
{
    if [[ $BSP_VER =~ 6.1.1 ]] ;  then

        export FMW_IMX=firmware-imx-8.19
        # firmware-sentinel-0.9 can not work
        export FMW_SENTINEL=firmware-sentinel-0.8
        export FMW_UPOWER=firmware-upower-1.2.0

    elif [[ $BSP_VER =~ 5.15.71 ]] ;  then

        export FMW_IMX=firmware-imx-8.18
        export FMW_SENTINEL=firmware-sentinel-0.8
        export FMW_UPOWER=firmware-upower-1.1.0

    fi

    if [ $BOARD == maaxboard-8ulp ] ; then
        export FMWS="$FMW_IMX $FMW_SENTINEL $FMW_UPOWER"
    else
        export FMWS="$FMW_IMX"
    fi

    export FMW_URL=https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/
    export FMW_PATH=$PRJ_PATH/firmware/
}

# parser configure file and export environment variable
function export_env()
{
    export BOARD=`jq -r ".bsp.board" $CONF_FILE | tr 'A-Z' 'a-z'`
    export BSP_VER=`jq -r ".bsp.version" $CONF_FILE | tr 'A-Z' 'a-z'`
    export GIT_URL=`jq -r ".bsp.giturl" $CONF_FILE | tr 'A-Z' 'a-z'`
    export CROSS_COMPILE=`jq -r ".bsp.cortexAtool" $CONF_FILE | tr 'A-Z' 'a-z'`
    export MCORE_COMPILE=`jq -r ".bsp.cortexMtool" $CONF_FILE | tr 'A-Z' 'a-z'`

    export SRCS="imx-atf uboot-imx imx-mkimage"
    export BRANCH=maaxboard_$BSP_VER
    export JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
    export ARCH=arm

    export_fmver

    if [ $BOARD == maaxboard-8ulp ] ; then

        SRCS="$SRCS mcore_sdk_8ulp"

        ATF_PLATFORM=imx8ulp
        IMX_BOOT_SOC_TARGET=iMX8ULP
        IMXBOOT_TARGETS=flash_singleboot_m33
        IMXBOOT_DTB=imx8ulp-evk.dtb
        MKIMG_BIN_PATH=$PRJ_PATH/imx-mkimage/iMX8ULP/

    elif [ $BOARD == maaxboard-mini ] ; then

        ATF_PLATFORM=imx8mm
        IMX_BOOT_SOC_TARGET=iMX8MM
        IMXBOOT_TARGETS=flash_ddr4_evk
        IMXBOOT_DTB=imx8mm-ddr4-evk.dtb
        MKIMG_BIN_PATH=$PRJ_PATH/imx-mkimage/iMX8M/

    elif [ $BOARD == maaxboard-nano ] ; then

        ATF_PLATFORM=imx8mn
        IMX_BOOT_SOC_TARGET=iMX8MN
        IMXBOOT_TARGETS=flash_ddr4_evk
        IMXBOOT_DTB=imx8mn-ddr4-evk.dtb
        MKIMG_BIN_PATH=$PRJ_PATH/imx-mkimage/iMX8M/

    elif [ $BOARD == maaxboard ] ; then

        ATF_PLATFORM=imx8mq
        IMX_BOOT_SOC_TARGET=iMX8M
        IMXBOOT_TARGETS=flash_ddr4_val
        IMXBOOT_DTB=imx8mq-ddr4-val.dtb
        MKIMG_BIN_PATH=$PRJ_PATH/imx-mkimage/iMX8M/

    fi
}

function do_fetch()
{
    cd $PRJ_PATH

    for src in $SRCS
    do
        if [ -d $src ] ; then
            pr_info "$src source code fetched already"
            continue
        fi

        pr_info "start fetch $src source code"
        git clone $GIT_URL/$src.git -b $BRANCH
    done


    mkdir -p $FMW_PATH && cd $FMW_PATH

    for fmw in $FMWS
    do
        if [ -d $fmw ] ; then
            pr_info "Firmware $fmw fetch already"
            continue
        fi
        pr_info "start fetch $fmw firmware"
        wget $FMW_URL/$fmw.bin

        bash $fmw.bin --auto-accept > /dev/null 2>&1
    done

    rm -f *.bin
}

function build_atf()
{
    SRC=imx-atf

    pr_warn "start build $SRC"
    cd $PRJ_PATH/${SRC}

    make -j${JOBS} CROSS_COMPILE=${CROSS_COMPILE} PLAT=$ATF_PLATFORM bl31

    set -x
    cp build/$ATF_PLATFORM/release/bl31.bin $MKIMG_BIN_PATH
    set +x
}

function build_cortexM()
{
    if [ $BOARD != maaxboard-8ulp ] ; then
        return ;
    fi

    SRC=mcore_sdk_8ulp

    pr_warn "start build $SRC"

    cd $PRJ_PATH/${SRC}
    cd boards/evkmimx8ulp/multicore_examples/rpmsg_lite_str_echo_rtos/armgcc

    export ARMGCC_DIR=$MCORE_COMPILE

    if [ ! -s release/rpmsg_lite_str_echo_rtos.bin ] ; then
        bash build_release.sh
    fi

    set -x
    cp release/rpmsg_lite_str_echo_rtos.bin $MKIMG_BIN_PATH/m33_image.bin
    set +x
}

function build_uboot()
{
    SRC=uboot-imx

    pr_warn "start build $SRC"
    cd $PRJ_PATH/${SRC}

    if [ ! -f .config ] ; then
        make ARCH=arm ${BOARD}_defconfig
    fi

    make -j${JOBS} CROSS_COMPILE=${CROSS_COMPILE} ARCH=arm

    set -x
    cp u-boot.bin $MKIMG_BIN_PATH
    cp u-boot-nodtb.bin $MKIMG_BIN_PATH
    cp spl/u-boot-spl.bin $MKIMG_BIN_PATH
    cp arch/arm/dts/${BOARD}.dtb $MKIMG_BIN_PATH/$IMXBOOT_DTB
    cp tools/mkimage $MKIMG_BIN_PATH/mkimage_uboot
    set +x
}

# The diagram below illustrate a signed iMX8 flash.bin image layout:
#   reference: uboot-imx/doc/imx/habv4/guides/mx8m_secure_boot.txt
#
#                     +-----------------------------+
#                     |                             |
#                     |     *Signed HDMI/DP FW      |
#                     |                             |
#                     +-----------------------------+
#                     |           Padding           |
#             ------- +-----------------------------+ --------
#                 ^   |          IVT - SPL          |   ^
#          Signed |   +-----------------------------+   |
#           Data  |   |        u-boot-spl.bin       |   |
#                 |   |              +              |   |  SPL
#                 v   |           DDR FW            |   | Image
#             ------- +-----------------------------+   |
#                     |      CSF - SPL + DDR FW     |   v
#                     +-----------------------------+ --------
#                     |           Padding           |
#             ------- +-----------------------------+ --------
#          Signed ^   |          FDT - FIT          |   ^
#           Data  |   +-----------------------------+   |
#                 v   |          IVT - FIT          |   |
#             ------- +-----------------------------+   |
#                     |          CSF - FIT          |   |
#             ------- +-----------------------------+   |  FIT
#                 ^   |       u-boot-nodtb.bin      |   | Image
#                 |   +-----------------------------+   |
#          Signed |   |       OP-TEE (Optional)     |   |
#           Data  |   +-----------------------------+   |
#                 |   |        bl31.bin (ATF)       |   |
#                 |   +-----------------------------+   |
#                 v   |          u-boot.dtb         |   v
#             ------- +-----------------------------+ --------
#
#
# Reference: <<IMX_LINUX_USERS_GUIDE.pdf>> 4.5.13 How to build imx-boot image by using imx-mkimage

function build_imxboot()
{
    SRC=imx-mkimage

    pr_warn "start build $SRC"
    cd $PRJ_PATH/${SRC}


    if [ $BOARD == maaxboard-8ulp ] ; then

        cp $FMW_PATH/firmware-upower-*/upower_a0.bin $MKIMG_BIN_PATH/upower.bin
        cp $FMW_PATH/firmware-sentinel-*/mx8ulpa0-ahab-container.img $MKIMG_BIN_PATH

    elif [ $BOARD == maaxboard ] ; then

        cp $FMW_PATH/firmware-imx-*/firmware/hdmi/cadence/signed_hdmi_imx8m.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_imem_1d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_dmem_1d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_imem_2d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_dmem_2d*.bin $MKIMG_BIN_PATH

    elif [ $BOARD == maaxboard-mini ] ; then

        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_imem_1d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_dmem_1d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_imem_2d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_dmem_2d*.bin $MKIMG_BIN_PATH

    elif [ $BOARD == maaxboard-nano ] ; then

        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_imem_1d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_dmem_1d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_imem_2d*.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_dmem_2d*.bin $MKIMG_BIN_PATH

    fi

    make SOC=$IMX_BOOT_SOC_TARGET REV=A0 $IMXBOOT_TARGETS

    cp $MKIMG_BIN_PATH/flash.bin u-boot-${BOARD}.imx
    chmod a+x u-boot-${BOARD}.imx

    cp u-boot-${BOARD}.imx $INST_PATH
}

function do_build()
{
    cd $PRJ_PATH

    mkdir -p $INST_PATH

    build_atf
    build_cortexM
    build_uboot
    build_imxboot
}

function do_install()
{
    cd $PRJ_PATH

    echo ""
    pr_info "bootloader installed to '$INST_PATH'"
    ls $INST_PATH && echo ""
}

function do_clean()
{
    for d in $SRCS
    do
        rm -rf $PRJ_PATH/$d
    done

    rm -rf $PRJ_PATH/firmware
    rm -rf $INST_PATH
}

#+-------------------------+
#| Shell script body entry |
#+-------------------------+

cd $PRJ_PATH

export_env

if [[ $# == 1 && $1 == -c ]] ;then
    pr_warn "start clean bootloader"
    do_clean
    exit;
fi

pr_warn "start build bootloader for ${BOARD}"

do_fetch

do_build

do_install
