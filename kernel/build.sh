#!/bin/bash

# this project absolute path
PRJ_PATH=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# top project absolute path
TOP_PATH=$(realpath $PRJ_PATH/..)

# binaries build prefix install path
PRFX_PATH=$PRJ_PATH/install

# binaries finally install path if needed
#INST_PATH=/tftp

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
    export BSP_VER=`jq -r ".bsp.version" $CONF_FILE`
    export GIT_URL=`jq -r ".bsp.giturl" $CONF_FILE | tr 'A-Z' 'a-z'`
    export BRANCH=`jq -r ".bsp.branch" $CONF_FILE`
    export CROSS_COMPILE=`jq -r ".bsp.cortexAtool" $CONF_FILE`

    if [[ ! -n $BRANCH ]] || [[ $BRANCH == null ]] ; then
        export BRANCH=maaxboard_$BSP_VER
    else
        export BSP_VER=$(echo $BRANCH | sed -E 's/.*(lf-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    fi

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
        pr_info "git clone $GIT_URL/linux-imx.git -b $BRANCH"
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

    if [ $BOARD == "maaxboard-8ulp" ] || [ $BOARD == "maaxboard-osm93" ]; then
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
        make -C $KER_PATH M=$PWD modules_install INSTALL_MOD_PATH=$PRFX_PATH INSTALL_MOD_STRIP=1
    fi
}

function do_install()
{
    pr_info "start install linux kernel images"

    cd $KER_PATH

    if [ -d $PRFX_PATH ] ; then
        rm -rf $PRFX_PATH/*
    fi
    mkdir -p $PRFX_PATH/overlays

    # Install image
    cp arch/arm64/boot/Image $PRFX_PATH
    cp arch/arm64/boot/dts/freescale/${BOARD}.dtb $PRFX_PATH
    cp arch/arm64/boot/dts/freescale/${BOARD}/*.dtbo $PRFX_PATH/overlays

    # Install kernel modules
    make modules_install INSTALL_MOD_PATH=$PRFX_PATH INSTALL_MOD_STRIP=1

    echo ""
    pr_info "linux kernel installed to '$PRFX_PATH'"
    ls $PRFX_PATH && echo ""

    if [[ -n "$INST_PATH" && -w $INST_PATH ]] ; then
        pr_info "install linux kernel to '$INST_PATH'"
        cp $PRFX_PATH/Image $INST_PATH
        cp $PRFX_PATH/${BOARD}.dtb $INST_PATH
    fi
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

    rm -rf $PRFX_PATH
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

