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

# parser configure file and export environment variable
function export_env()
{
    export BOARD=`jq -r ".bsp.board" $CONF_FILE | tr 'A-Z' 'a-z'`
    export BSP_VER=`jq -r ".bsp.version" $CONF_FILE | tr 'A-Z' 'a-z'`
    export GIT_URL=`jq -r ".bsp.giturl" $CONF_FILE | tr 'A-Z' 'a-z'`
    export CROSS_COMPILE=`jq -r ".bsp.crosstool" $CONF_FILE | tr 'A-Z' 'a-z'`

    export BRANCH=maaxboard_$BSP_VER
    export KER_PATH=$PRJ_PATH/linux-imx

    export JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
    export ARCH=arm64
    export SRCS="linux-imx mwifiex"
}

function build_kernel()
{
    cd $PRJ_PATH

    if [ -d $KER_PATH ] ; then
        pr_info "linux kernel source code fetched already"
    else
        pr_info "start fetch linux kernel source code"
        git clone $GIT_URL/linux-imx.git -b $BRANCH
    fi

    pr_info "Start build linux kernel source code"

    cd $KER_PATH

    if [ ! -s .config ] ; then
        make ${BOARD}_defconfig
    fi

    make -j ${JOBS}
}

function build_driver()
{
    cd $PRJ_PATH

    if [ $BOARD == "maaxboard-8ulp" ] ; then
        pr_info "Start build WiFi driver for $BOARD"

        WIFI_BRANCH=`echo $BSP_VER | sed 's/-/_/2'`

        if [ ! -d mwifiex ] ; then
            pr_info "start fetch wifi driver source code"
            git clone https://github.com/nxp-imx/mwifiex.git -b $WIFI_BRANCH
        else
            pr_info "wifi driver source code fetched already"
        fi

        cd mwifiex/mxm_wifiex/wlan_src/

        make -C $KER_PATH M=$PWD
        make -C $KER_PATH M=$PWD modules_install INSTALL_MOD_PATH=$INST_PATH INSTALL_MOD_STRIP=1
    fi
}

function do_install()
{
    pr_info "start install linux kernel images"

    cd $KER_PATH

    if [ -d $INST_PATH ] ; then
        rm -rf $INST_PATH/*
    fi
    mkdir -p $INST_PATH/overlays

    # Install image
    cp arch/arm64/boot/Image $INST_PATH
    cp arch/arm64/boot/dts/freescale/${BOARD}.dtb $INST_PATH
    cp arch/arm64/boot/dts/freescale/${BOARD}/*.dtbo $INST_PATH/overlays

    # Install kernel modules
    make modules_install INSTALL_MOD_PATH=$INST_PATH INSTALL_MOD_STRIP=1

    echo ""
    pr_info "linux kernel installed to '$INST_PATH'"
    ls $INST_PATH && echo ""
}

function do_build()
{
    cd $PRJ_PATH

    build_kernel

    do_install

    build_driver
}

function do_clean()
{
    cd $PRJ_PATH

    for d in $SRCS
    do
        rm -rf $PRJ_PATH/$d
    done

    rm -rf $INST_PATH
}

#+-------------------------+
#| Shell script body entry |
#+-------------------------+

export_env

if [[ $# == 1 && $1 == -c ]] ;then
    pr_warn "start clean linux kernel"
    do_clean
    exit;
fi

pr_warn "start build linux kernel for ${BOARD}"

do_build

