#!/bin/bash

# this shell script relative path
SCRIPT_PATH=`dirname ${BASH_SOURCE[0]}`

function pr_red() {
    echo -e "\033[40;31m $1 \033[0m"
}

function pr_yellow() {
    echo -e "\033[40;33m $1 \033[0m"
}

function pr_green() {
    echo -e "\033[40;32m $1 \033[0m"
}

function setup_build_env()
{
    # build jobs
    export JOBS=`cat /proc/cpuinfo | grep processor | wc -l`

    # script tools directory absolute path
    export TOOLS_PATH=`realpath $SCRIPT_PATH`

    # project absolute path
    export PJ_PATH=`realpath ${SCRIPT_PATH}/../`

    # build directory
    export BD_PATH=$PJ_PATH/build

    # configure file
    export CONF_FILE=${TOOLS_PATH}/config.json
    export BOARD=`jq -r ".common.board" $CONF_FILE`
    export BSP_VERSION=`jq -r ".common.bsp" $CONF_FILE`
    export CROSSTOOL=`jq -r ".common.crosstool" $CONF_FILE`

    # working path
    export BL_PATH=$BD_PATH/bootloader
    export KR_PATH=$BD_PATH/kernel
    export IMG_PATH=$BD_PATH/images
    export FS_PATH=$BD_PATH/rootfs
    export TMP_PATH=$BD_PATH/tmp

    # alias commands
    alias cdpj='cd $PJ_PATH'
    alias cdbl='cd $BL_PATH'
    alias cdkr='cd $KR_PATH'
    alias cdfs='cd $FS_PATH'
    alias cdbd='cd $BD_PATH'
    alias cdimg='cd $IMG_PATH'
    alias cdtool='cd $TOOLS_PATH'

    mkdir -p $BL_PATH
    mkdir -p $KR_PATH
    mkdir -p $FS_PATH
    mkdir -p $IMG_PATH
    mkdir -p $TMP_PATH

    ln -sf $TOOLS_PATH/build_uboot.sh  $BL_PATH/build.sh
    ln -sf $TOOLS_PATH/build_kernel.sh $KR_PATH/build.sh
    ln -sf $TOOLS_PATH/build_rootfs.sh $FS_PATH/build.sh
    ln -sf $TOOLS_PATH/build_image.sh  $IMG_PATH/build.sh
}

function check_sudo()
{
    pr_red "Build system images need root privilege, please input password for sudo here: "
    read -s -p "Password: " pwd_sudo && echo ""
    read -s -p "Retype  : " pwd_again && echo ""

    if [[ "$pwd_sudo" != "$pwd_again" ]] ; then
        pr_red "Sorry, passwords do not match, stop build $target now."
        return 1;
    fi
    echo ""
}

function build()
{
    if [ $# != 1 ] ; then

        pr_yellow "\n### Shell environment set up for builds. ###\n"

        pr_yellow "You can now run 'build <target>', and common targets are:\n"

        pr_green "\tbootloader: Build bootloader only."
        pr_green "\tkernel    : Build linux kernel only."
        pr_green "\timage     : Build system image only."
        pr_green "\tsdk       : Build all the above targets together."

        echo ""
        pr_yellow "Example for build SDK system image:\n"
        pr_green "\t1. cp /path/to/rootfs-xxx.tar.bz2 ./rootfs/rootfs.tar.bz2"
        pr_green "\t2. build sdk\n"

        return 0;
    fi

    target=$1

    if [[ $target =~ boot ]] ; then
        cd $BL_PATH && ./build.sh

    elif [[ $target =~ kernel || $target =~ linux ]] ; then
        cd $KR_PATH && ./build.sh

    elif [[ $target =~ image ]] ; then

        if ! check_sudo ; then
            return ;
        fi

        cd $FS_PATH
        if ! ./build.sh  ; then
            return ;
        fi

        cd $IMG_PATH && echo $pwd_sudo | sudo -S bash build.sh

    elif [[ $target = sdk ]] ; then

        if ! check_sudo ; then
            return ;
        fi

        cd $BL_PATH
        if ! ./build.sh  ; then
            return ;
        fi

        cd $KR_PATH
        if ! ./build.sh  ; then
            return ;
        fi

        cd $FS_PATH
        if ! ./build.sh  ; then
            return ;
        fi

        cd $IMG_PATH && echo $pwd_sudo | sudo -S bash build.sh

    elif [[ $target == -c ]] ; then

        pr_red "do you really want to remove the build folder? [y/n] "
        read confirm

        if [[ $confirm == y ]] ; then
            rm -rf $BD_PATH
        fi
        return 0;

    else
        pr_red "ERROR: Unknow build target: $target"
        return 1;
    fi

}

if ! command -v jq > /dev/null 2>&1 ; then
    pr_red "ERROR: Please run $SCRIPT_PATH/setup_tools.sh as root to install system tools."
    return ;
fi

setup_build_env

build

if [ -d $BD_PATH ] ; then
    cd $BD_PATH && pwd && ls && echo ""
fi
