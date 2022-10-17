#!/bin/bash

if [ -z $TOOLS_PATH ] ; then
    echo "please source source.sh first"
    exit
fi

. $TOOLS_PATH/func_tools.sh
pr_warn "start build bootloader"
set -e

SOC=iMX8ULP
MKIMG_BIN_PATH=$BL_PATH/imx-mkimage/${SOC}/

function do_fetch()
{
    cd $BL_PATH

    SRCS="imx-atf m33-sdk uboot-imx imx-mkimage"
    for src in $SRCS
    do
        if [ -d $src ] ; then
            pr_info "$src fetched already"
            continue
        fi

        pr_info "start fetch $src source code"
        do_fetch_git $src
    done

    cd $BL_PATH
    if [ -d firmware ] ; then
        pr_info "firmware fetched already"
        return ;
    fi

    do_fetch_firmware
}

function build_atf()
{
    SRC=imx-atf

    pr_warn "start build $SRC"
    cd $BL_PATH/${SRC}

    make -j${JOBS} CROSS_COMPILE=${CROSSTOOL} PLAT=imx8ulp bl31

    set -x
    cp build/imx8ulp/release/bl31.bin $MKIMG_BIN_PATH
    set +x
}

function build_cortexM()
{
    SRC=m33-sdk

    pr_warn "start build $SRC"

    cd $BL_PATH/${SRC}
    cd boards/evkmimx8ulp/multicore_examples/rpmsg_lite_str_echo_rtos/armgcc

    export ARMGCC_DIR=$CM33TOOL

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
    cd $BL_PATH/${SRC}

    if [ ! -f .config ] ; then
        make ARCH=arm maaxboard_8ulp_defconfig
    fi

    make -j${JOBS} CROSS_COMPILE=${CROSSTOOL} ARCH=arm

    set -x
    cp u-boot.bin $MKIMG_BIN_PATH
    cp spl/u-boot-spl.bin $MKIMG_BIN_PATH
    cp arch/arm/dts/maaxboard-8ulp.dtb $MKIMG_BIN_PATH
    set +x
}


function build_firmware()
{
    SRC=firmware

    pr_warn "start build $SRC"
    cd $BL_PATH/${SRC}

    set -x
    cp firmware-upower-*/upower.bin $MKIMG_BIN_PATH
    cp firmware-sentinel-*/mx8ulpa0-ahab-container.img $MKIMG_BIN_PATH
    set +x
}


function build_imxboot()
{
    SRC=imx-mkimage

    pr_warn "start build $SRC"
    cd $BL_PATH/${SRC}

    make SOC=$SOC flash_singleboot_m33

    cp $SOC/flash.bin u-boot-${BOARD}.imx
    chmod a+x u-boot-${BOARD}.imx

    set -x
    cp u-boot-${BOARD}.imx $BL_PATH
    set +x
}

function do_build()
{
    cd $BL_PATH

    build_atf
    build_cortexM
    build_uboot
    build_firmware
    build_imxboot
}

function do_install()
{
    cd $BL_PATH

    set -x
    cp imx-mkimage/u-boot-${BOARD}.imx $TMP_PATH
    cp imx-mkimage/u-boot-${BOARD}.imx $IMG_PATH
    set +x
}

function do_clean()
{
    cd $BL_PATH

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

do_fetch

do_build

do_install

