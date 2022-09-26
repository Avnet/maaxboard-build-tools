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

    systools="coreutils jq wget curl tree gawk sed unzip cpio lz4 lzop zstd rsync kmod kpartx \
	desktop-file-utils iputils-ping xterm diffstat chrpath asciidoc docbook-utils help2man \
        build-essential gcc g++ make cmake automake groff socat flex texinfo bison texi2html \
        git cvs subversion mercurial autoconf autoconf-archive \
        python python3 python3-pip python3-pexpect python-pysqlite2 python3-git python3-jinja2 \
        lib32z1 libssl-dev libncurses-dev lib32ncurses-dev libgl1-mesa-dev libglu1-mesa-dev \
	libsdl1.2-dev "

    apt update > /dev/null 2>&1
    apt install -y $systools
}

function install_crosstool()
{
    ARMTOOL_VER=11.2-2022.02
    ARMTOOL_URL=https://developer.arm.com/-/media/Files/downloads/gnu/$ARMTOOL_VER/binrel/
    ARMTOOL_NAME=gcc-arm-$ARMTOOL_VER-x86_64-aarch64-none-linux-gnu

    if [ -d /opt/$ARMTOOL_NAME ]  ; then
        pr_info "All development tools already installed, skip it"
        return 0;
    fi

    pr_info "start apt install devlopment tools(commands)"

    devtools="u-boot-tools mtd-utils device-tree-compiler binfmt-support qemu qemu-user-static \
	    debootstrap debian-archive-keyring "

    cortexM_tool="gcc-arm-none-eabi"

    # Cross compiler from Ubuntu official apt repository
    #cortexA_tool="gcc-aarch64-linux-gnu"

    apt install -y $devtools $cortexM_tool $cortexA_tool

    # NXP document suggest cross compiler from ARM Developer
    #   https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads

    pr_info "start downalod cross compiler from ARM Developer"

    if [ ! -s $ARMTOOL_NAME.tar.xz ] ; then
        wget $ARMTOOL_URL/$ARMTOOL_NAME.tar.xz
    fi

    tar -xJf $ARMTOOL_NAME.tar.xz -C /opt
    rm -f $ARMTOOL_NAME.tar.xz

    /opt/$ARMTOOL_NAME/bin/aarch64-none-linux-gnu-gcc -v
    pr_info "cross compiler installed to \"/opt/$ARMTOOL_NAME\" successfully"
}

echo ""

set -e

install_systools

install_crosstool

