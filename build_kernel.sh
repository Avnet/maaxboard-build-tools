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
    SRC=linux-imx

    cd $KR_PATH

    if [ -d $SRC ] ; then
        pr_info "$SRC fetched already"
        return;
    fi

    pr_info "start fetch $SRC source code"
    do_fetch_git $SRC
}

function do_build()
{
    SRC=linux-imx

    pr_warn "start build $SRC"
    cd $KR_PATH/${SRC}

    export ARCH=arm64
    export CROSS_COMPILE=${CROSSTOOL}

    if [ ! -f .config ] ; then
        make ARCH=${ARCH} maaxboard_8ulp_defconfig
    fi

    make -j${JOBS} CROSS_COMPILE=${CROSSTOOL} ARCH=${ARCH}
}

function do_install()
{
    pr_warn "start install linux kernel image and drivers"
    cd $KR_PATH/linux-imx

    export ARCH=arm64
    export CROSS_COMPILE=${CROSSTOOL}

    rm -rf $TMP_PATH/lib/modules
    make modules_install INSTALL_MOD_PATH=$TMP_PATH INSTALL_MOD_STRIP=1

    set -x
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

