#!/bin/bash

if [ -z $TOOLS_PATH ] ; then
    echo "please source source.sh first"
    exit;
fi

. $TOOLS_PATH/func_tools.sh
pr_warn "start build linux kernel"
set -e

function do_fetch()
{
    cd $KR_PATH

    SRCS="linux-imx mwifiex"
    for src in $SRCS
    do
        if [ -d $src ] ; then
            pr_info "$src fetched already"
            continue
        fi

        pr_info "start fetch $src source code"
        do_fetch_git $src
    done
}

function do_build()
{
    KERNEL=linux-imx

    pr_warn "start build $KERNEL"
    cd $KR_PATH/${KERNEL}

    export ARCH=arm64
    export CROSS_COMPILE=${CROSSTOOL}

    if [ ! -f .config ] ; then
        make ARCH=${ARCH} maaxboard_8ulp_defconfig
    fi
    make -j${JOBS} CROSS_COMPILE=${CROSSTOOL} ARCH=${ARCH}

    pr_warn "start build wireless module driver"
    cd $KR_PATH/mwifiex/mxm_wifiex/wlan_src/
    make -j${JOBS} CROSS_COMPILE=${CROSSTOOL} ARCH=${ARCH} KERNELDIR=$KR_PATH/${KERNEL}
}

function do_install()
{
    export ARCH=arm64
    export CROSS_COMPILE=${CROSSTOOL}

    pr_warn "remove old modules in $TMP_PATH"
    rm -rf $TMP_PATH/lib/modules

    pr_warn "start install linux kernel image and drivers"
    cd $KR_PATH/linux-imx
    make modules_install INSTALL_MOD_PATH=$TMP_PATH INSTALL_MOD_STRIP=1

    pr_warn "start install wireless driver"
    cd $KR_PATH/mwifiex/mxm_wifiex/wlan_src/
    make -C $KR_PATH/${KERNEL} M=$PWD CROSS_COMPILE=${CROSSTOOL} ARCH=${ARCH} modules_install INSTALL_MOD_PATH=$TMP_PATH INSTALL_MOD_STRIP=1

    set -x
    cd $KR_PATH/linux-imx
    mkdir -p $TMP_PATH/boot/overlays
    cp arch/arm64/boot/Image $TMP_PATH/boot/
    cp arch/arm64/boot/dts/freescale/${BOARD}.dtb $TMP_PATH/boot/
    cp arch/arm64/boot/dts/freescale/overlays/*.dtbo $TMP_PATH/boot/overlays/
    set +x
}

function do_clean()
{
    cd $KR_PATH

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

