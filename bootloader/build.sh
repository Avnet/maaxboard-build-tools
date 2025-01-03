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
    if [[ $BSP_VER =~ 6.6.36 ]] ;  then

        export FMW_IMX=firmware-imx-8.25-27879f8
        export FMW_UPOWER=firmware-upower-1.3.1
        export FMW_SENTINEL=firmware-ele-imx-0.1.3-4b30ee5

    elif [[ $BSP_VER =~ 6.6.3 ]] ;  then

        export FMW_IMX=firmware-imx-8.23
        export FMW_UPOWER=firmware-upower-1.3.1
        export FMW_SENTINEL=firmware-ele-imx-0.1.1

    elif [[ $BSP_VER =~ 6.1.22 ]] ;  then

        export FMW_IMX=firmware-imx-8.20
        export FMW_SENTINEL=firmware-sentinel-0.10
        export FMW_UPOWER=firmware-upower-1.3.0

    elif [[ $BSP_VER =~ 6.1.1 ]] ;  then

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
    elif [ $BOARD == maaxboard-osm93 ] ; then
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
    export BSP_VER=`jq -r ".bsp.version" $CONF_FILE`
    export GIT_URL=`jq -r ".bsp.giturl" $CONF_FILE | tr 'A-Z' 'a-z'`
    export BRANCH=`jq -r ".bsp.branch" $CONF_FILE`
    export CROSS_COMPILE=`jq -r ".bsp.cortexAtool" $CONF_FILE`
    export MCORE_COMPILE=`jq -r ".bsp.cortexMtool" $CONF_FILE`

    if [[ ! -n $BRANCH ]] || [[ $BRANCH == null ]] ; then
        export BRANCH=maaxboard_$BSP_VER
    else
        export BSP_VER=$(echo $BRANCH | sed -E 's/.*(lf-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    fi

    export SRCS="imx-atf uboot-imx imx-mkimage"
    export JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
    export ARCH=arm

    export_fmver

    # Default set A0 silicon for other MaaXBoard(not used).
    export IMX_SOC_REV=A0

    if [ $BOARD == maaxboard-8ulp ] ; then

        MCORE_SDK=mcore_sdk_8ulp
        MCORE_EVK=evkmimx8ulp
        SRCS="$SRCS $MCORE_SDK"

        # MaaXBoard-8ULP manufacture on 2023.09 using A2 silicon
        IMX_SOC_REV=A2
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

    elif [ $BOARD == maaxboard-osm93 ] ; then

        #If the current MaaXBoard-OSM93 version already supports machine learning,
        #the M33 core compilation in U-Boot needs to be disabled.
        #MCORE_SDK=mcore_sdk_93

        IMX_SOC_REV=A1
        SRCS="$SRCS $MCORE_SDK"

        MCORE_EVK=mcimx93evk
        ATF_PLATFORM=imx93
        IMXBOOT_DTB=imx93-11x11-evk.dtb

        if [ -z $MCORE_SDK ] ; then
            IMXBOOT_TARGETS=flash_singleboot
        else
            IMXBOOT_TARGETS=flash_singleboot_m33
        fi

        if [ $IMX_SOC_REV == A0 ] ; then
            IMX_BOOT_SOC_TARGET=iMX9
            MKIMG_BIN_PATH=$PRJ_PATH/imx-mkimage/iMX9/
        elif [ $IMX_SOC_REV == A1 ] ; then
             IMX_BOOT_SOC_TARGET=iMX93
             MKIMG_BIN_PATH=$PRJ_PATH/imx-mkimage/iMX93/
        fi

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
        pr_info "git clone $GIT_URL/$src.git -b $BRANCH"
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
    if [ -z "$MCORE_SDK" ] ; then
        return 0;
    fi

    SRC=$MCORE_SDK
    DEMO_PATH=boards/$MCORE_EVK/multicore_examples/rpmsg_lite_str_echo_rtos/armgcc
    DEMO_BIN=release/rpmsg_lite_str_echo_rtos.bin
    IMG_NAME=${BOARD/-/_}_m33_image.bin

    pr_warn "start build $SRC"

    cd $PRJ_PATH/${SRC}
    cd $DEMO_PATH

    export ARMGCC_DIR=$MCORE_COMPILE

    #bash clean.sh
    if [ ! -s $DEMO_BIN ] ; then
        bash build_release.sh
    fi

    # For Yocto
    set -x
    cp $DEMO_BIN $MKIMG_BIN_PATH/m33_image.bin
    cp $DEMO_BIN $PRFX_PATH/$IMG_NAME
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

        REV=`echo $IMX_SOC_REV | tr [A-Z] [a-z]`
        if [ $REV == a2 ] ; then
            UPOWER_REV=a1
        else
            UPOWER_REV=a0
        fi
        cp $FMW_PATH/$FMW_UPOWER/upower_${UPOWER_REV}.bin $MKIMG_BIN_PATH/upower.bin
        cp $FMW_PATH/$FMW_SENTINEL/mx8ulp${REV}-ahab-container.img $MKIMG_BIN_PATH

    elif [ $BOARD == maaxboard-osm93 ] ; then

        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/lpddr4_[id]mem_[12]d*.bin $MKIMG_BIN_PATH
        if [ $IMX_SOC_REV == A0 ] ; then
            cp $FMW_PATH/firmware-sentinel-*/mx93a0-ahab-container.img $MKIMG_BIN_PATH
        elif [ $IMX_SOC_REV == A1 ] ; then
            cp $FMW_PATH/firmware-ele-imx-*/mx93a1-ahab-container.img $MKIMG_BIN_PATH
        fi

    elif [ $BOARD == maaxboard ] ; then

        cp $FMW_PATH/firmware-imx-*/firmware/hdmi/cadence/signed_hdmi_imx8m.bin $MKIMG_BIN_PATH
        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_[id]mem_[12]d*.bin $MKIMG_BIN_PATH

    elif [ $BOARD == maaxboard-mini ] ; then

        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_[id]mem_[12]d*.bin $MKIMG_BIN_PATH

    elif [ $BOARD == maaxboard-nano ] ; then

        cp $FMW_PATH/firmware-imx-*/firmware/ddr/synopsys/ddr4_[id]mem_[12]d*.bin $MKIMG_BIN_PATH

    fi

    REV=`echo $IMX_SOC_REV | tr [a-z] [A-Z]`
    pr_info "make SOC=$IMX_BOOT_SOC_TARGET REV=$REV $IMXBOOT_TARGETS"
    make SOC=$IMX_BOOT_SOC_TARGET REV=$REV $IMXBOOT_TARGETS

    cp $MKIMG_BIN_PATH/flash.bin u-boot-${BOARD}.imx
    chmod a+x u-boot-${BOARD}.imx

    cp u-boot-${BOARD}.imx $PRFX_PATH
}

function do_build()
{
    cd $PRJ_PATH

    mkdir -p $PRFX_PATH

    build_atf
    build_cortexM
    build_uboot
    build_imxboot
}

function do_install()
{
    cd $PRJ_PATH

    echo ""
    pr_info "bootloader installed to '$PRFX_PATH'"
    ls $PRFX_PATH && echo ""

    if [[ -n "$INST_PATH" && -w $INST_PATH ]] ; then
        pr_info "install bootloader to '$INST_PATH'"
        cp $PRFX_PATH/u-boot-${BOARD}.imx $INST_PATH
    fi
}

function do_clean()
{
    for d in $SRCS
    do
        rm -rf $PRJ_PATH/$d
    done

    rm -rf $PRJ_PATH/firmware
    rm -rf $PRFX_PATH
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
