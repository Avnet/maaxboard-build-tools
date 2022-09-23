#!/bin/bash

if [ -z $TOOLS_PATH ] ; then
    echo "please source source.sh first"
    exit 1;
fi

. $TOOLS_PATH/func_tools.sh
pr_warn "start build rootfs source"
set -e

function do_fetch()
{
    cd $FS_PATH

    if [ -d rootfs ] ; then
        pr_info "rootfs fetched already"
        return ;
    fi

    pr_info "start fetch $src source code"

    rootfs_tar=`jq -r .image.rootfs $CONF_FILE`
    if [[ $rootfs_tar == null || -z $rootfs_tar ]] ; then
        pr_error "rootfs file not found in configure file"
        exit 1;
    fi

    rootfs_tar=`eval echo $rootfs_tar`
    if [ ! -s $rootfs_tar ] ; then
        pr_error "rootfs file '$rootfs_tar' not exist"
        exit 1;
    fi

    do_unpack $rootfs_tar $FS_PATH/rootfs
}

function do_install()
{
    pr_warn "start install files to rootfs"
    cd $FS_PATH/

    # install uEnv.txt
    cp $TOOLS_PATH/files/boot/* $TMP_PATH/boot

    # install linux kernel modules
    rm -rf $FS_PATH/rootfs/lib/modules/[1-9].*.*-*
    cp -af $TMP_PATH/lib/modules $FS_PATH/rootfs/lib/

    # install bin files
    cp $TOOLS_PATH/files/bin/* $FS_PATH/rootfs/usr/sbin/
}

function do_modify()
{
    pr_warn "modify configure file in rootfs"
    cd $FS_PATH/

    if ! grep "^alias ls=" rootfs/etc/profile > /dev/null 2>&1 ; then
       echo "alias ls='ls --color=auto'" >> rootfs/etc/profile
    fi
}

function do_clean()
{
    cd $FS_PATH

    for f in `ls`
    do
        if [[ $f != build.sh ]] ; then
            rm -rf $f
        fi
    done
}

if [[ $# == 1 && $1 == -c ]] ;then
    do_clean
    exit 0;
fi

do_fetch

do_install

do_modify

