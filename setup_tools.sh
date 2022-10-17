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
        bc git cvs subversion mercurial autoconf autoconf-archive \
        python3 python3-pip python3-pexpect python3-git python3-jinja2 \
        lib32z1 libssl-dev libncurses-dev lib32ncurses-dev libgl1-mesa-dev libglu1-mesa-dev \
    libsdl1.2-dev "

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

    CortexA_PACK=gcc-arm-$ARMTOOL_VER-`uname -p`-aarch64-none-linux-gnu
    CortexA_URL=https://developer.arm.com/-/media/Files/downloads/gnu-a/$ARMTOOL_VER/binrel/
    CortexA_NAME=gcc-arm-$ARMTOOL_VER

    if [ -d /opt/$CortexA_NAME ]  ; then
        pr_info "Cortex-A crosstool $CortexA_NAME installed already, skip it"
    else
        pr_info "start download cross compiler from ARM Developer for Cortex-A core"
        if [ ! -s $CortexA_PACK.tar.xz ] ; then
            wget $CortexA_URL/$CortexA_PACK.tar.xz
        fi

        tar -xJf $CortexA_PACK.tar.xz -C /opt
        rm -f $CortexA_PACK.tar.xz

        mv /opt/$CortexA_PACK /opt/$CortexA_NAME

        /opt/$CortexA_NAME/bin/aarch64-none-linux-gnu-gcc -v
        pr_info "cross compiler for Cortex-A installed to \"/opt/$CortexA_NAME\" successfully"
    fi

    # Cross compiler from Ubuntu official apt repository
    if command -v arm-none-eabi-gcc > /dev/null 2>&1 ; then
        pr_info "Cortex-M crosstool arm-none-eabi-gcc installed already, skip it"
	else
		pr_info "start install cross compiler from apt repository for Cortex-M/A core"
		apt install -y gcc-arm-none-eabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
		arm-none-eabi-gcc -v
	fi
}

echo ""
set -e

install_systools

install_devtools

install_crosstool

