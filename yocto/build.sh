#!/bin/bash

# bitbake target
BB_TARGET=avnet-image-full

# this project absolute path
PRJ_PATH=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# top project absolute path
TOP_PATH=$(realpath $PRJ_PATH/..)

# binaries install path
INST_PATH=$PRJ_PATH/install

# config file path
CONF_FILE=$TOP_PATH/config.json

# Download path
DL_PATH="/srv/ftp/yocto/oe-sources-langdale/"

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
    export YCT_VER=`jq -r ".system.version" $CONF_FILE | tr 'A-Z' 'a-z'`

    export YCT_PATH=$PRJ_PATH/$YCT_VER-$BSP_VER
    export BUILD_DIR=${BOARD}/build

    export BRANCH=maaxboard_$BSP_VER
}

function do_fetch()
{
    mkdir -p $YCT_PATH && cd $YCT_PATH

    if [ ! -d sources ] ; then
        pr_info "start repo fetch Yocto $YCT_VER source code"

        if ! command -v repo > /dev/null 2>&1 ; then
            curl https://storage.googleapis.com/git-repo-downloads/repo > repo
            chmod a+x repo
            export PATH=$YCT_PATH:$PATH
        fi

        BSP_VER=`echo $BSP_VER | sed 's/lf/imx/'`
        repo init -u https://github.com/nxp-imx/imx-manifest -b imx-linux-$YCT_VER -m $BSP_VER.xml
        repo sync && rm -f repo

    else
        pr_warn "Yocto $YCT_VER source code fetched already"
    fi

    if [ ! -d sources/meta-maaxboard ] ; then
        pr_info "start git clone Yocto meta-maaxboard"

        cd sources

        git clone $GIT_URL/meta-maaxboard.git -b $YCT_VER
    else
        pr_warn "Yocto meta-maaxboard fetched already"
    fi
}

function do_build()
{
    cd $YCT_PATH

    if [ ! -f ${BUILD_DIR}/conf/local.conf ] ; then
        pr_info "source maaxboard-setup.sh"
        MACHINE=${BOARD} source sources/meta-maaxboard/tools/maaxboard-setup.sh -b $BUILD_DIR
    else
        pr_info "source poky/oe-init-build-env"
        source sources/poky/oe-init-build-env $BUILD_DIR
    fi

    if [[ -n "$DL_PATH" ]] ; then
        sed -i "s|^#DL_DIR.*|DL_DIR ?= \"$DL_PATH\"|g" conf/local.conf
        sed -i "s|^DL_DIR.*|DL_DIR ?= \"$DL_PATH\"|g" conf/local.conf
    fi

    bitbake $BB_TARGET
}

function do_install()
{
    cd $YCT_PATH

    echo ""
    pr_info "Yocto(YCT_VER) installed to '$INST_PATH'"

    mkdir -p ${INST_PATH}
    cp $BUILD_DIR/tmp/deploy/images/$BOARD/$BB_TARGET-$BOARD-*.rootfs.tar.zst ${INST_PATH}/rootfs.tar.zst
    cp $BUILD_DIR/tmp/deploy/images/$BOARD/imx-boot ${INST_PATH}/u-boot-${BOARD}.bin
    chmod a+x ${INST_PATH}/u-boot-${BOARD}.bin
    cp $BUILD_DIR/tmp/deploy/images/$BOARD/$BB_TARGET-$BOARD.wic.zst ${INST_PATH}

    ls ${INST_PATH} && echo ""
}

function do_clean()
{
    cd $PRJ_PATH

    rm -rf $INST_PATH
}

#+-------------------------+
#| Shell script body entry |
#+-------------------------+

export_env

if [[ $# == 1 && $1 == -c ]] ;then
    pr_warn "start clean Yocto source code"
    do_clean
    exit;
fi

pr_warn "start build Yocto $YCT_VER for ${BOARD}"

do_fetch

do_build

do_install
