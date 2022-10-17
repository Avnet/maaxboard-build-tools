#!/bin/bash
# This shell script used to system tools

# display in red
function pr_error() {
    echo -e "\033[40;31m --E-- $1 \033[0m\n"
}

# display in green
function pr_info() {
    echo -e "\033[40;32m --I-- $1 \033[0m\n"
}

if [ `id -u` != 0 ] ; then
    pr_error "This shell script must be excuted as root privilege"
    exit;
fi

function install_systools()
{
    if command -v jq > /dev/null 2>&1 ; then
        pr_info "All system tools already installed, skip it"
        return 0;
    fi

    pr_info "start apt install system tools(commands)"

    systools="coreutils jq wget curl tree gawk sed unzip cpio bc lzop zstd rsync kmod kpartx \
        desktop-file-utils iputils-ping xterm diffstat chrpath asciidoc docbook-utils help2man \
        build-essential gcc g++ make cmake automake groff socat flex texinfo bison texi2html \
        git cvs subversion mercurial autoconf autoconf-archive parted dosfstools \
        python3 python3-pip python3-pexpect python3-git python3-jinja2 \
        lib32z1 libssl-dev libncurses-dev libgl1-mesa-dev libglu1-mesa-dev libsdl1.2-dev "

    apt update > /dev/null 2>&1
    apt install -y $systools
}


function install_devtools()
{
    if command -v debootstrap > /dev/null 2>&1 ; then
        pr_info "All development tools already installed, skip it"
        return 0;
    fi

    pr_info "start apt install devlopment tools(commands)"

    devtools="u-boot-tools mtd-utils device-tree-compiler binfmt-support \
                qemu qemu-user-static debootstrap debian-archive-keyring "

    apt install -y $devtools
}


# NXP document suggest cross compiler from ARM Developer:
#   https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
function install_crosstool()
{
    ARMTOOL_VER=10.3-2021.07

    CortexM_PACK=gcc-arm-none-eabi-$ARMTOOL_VER-`uname -p`-linux
    CortexM_TAR=$CortexM_PACK.tar.bz2
    CortexM_URL=https://developer.arm.com/-/media/Files/downloads/gnu-rm/$ARMTOOL_VER/
    CortexM_NAME=gcc-arm-none-eabi-$ARMTOOL_VER

    # Crosstool for Cortex-M download from ARM Developer

    if [ -d /opt/$CortexM_NAME ]  ; then
        pr_info "Cortex-M crosstool $CortexM_NAME installed already, skip it"
    else
        pr_info "start download cross compiler from ARM Developer for Cortex-M core"
        if [ ! -s $CortexM_TAR ] ; then
            wget $CortexM_URL/$CortexM_TAR
        fi

        tar -xjf $CortexM_TAR -C /opt
        rm -f $CortexM_TAR

        /opt/$CortexM_NAME/bin/arm-none-eabi-gcc -v
        pr_info "cross compiler for Cortex-M installed to \"/opt/$CortexM_NAME\" successfully"
    fi

    # Crosstool for Cortex-A download from ARM Developer

    CortexA_PACK=gcc-arm-$ARMTOOL_VER-`uname -p`-aarch64-none-linux-gnu
    CortexA_TAR=$CortexA_PACK.tar.xz
    CortexA_URL=https://developer.arm.com/-/media/Files/downloads/gnu-a/$ARMTOOL_VER/binrel/
    CortexA_NAME=gcc-arm-$ARMTOOL_VER

    if [ -d /opt/$CortexA_NAME ]  ; then
        pr_info "Cortex-A crosstool $CortexA_NAME installed already, skip it"
    else
        pr_info "start download cross compiler from ARM Developer for Cortex-A core"
        if [ ! -s $CortexA_TAR ] ; then
            wget $CortexA_URL/$CortexA_TAR
        fi

        tar -xJf $CortexA_TAR -C /opt
        rm -f $CortexA_TAR

        mv /opt/$CortexA_PACK /opt/$CortexA_NAME

        /opt/$CortexA_NAME/bin/aarch64-none-linux-gnu-gcc -v
        pr_info "cross compiler for Cortex-A installed to \"/opt/$CortexA_NAME\" successfully"
    fi
}

echo ""
set -e

install_systools

install_devtools

install_crosstool

