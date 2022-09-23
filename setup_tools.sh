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

    systools="gawk wget git diffstat unzip texinfo build-essential chrpath socat libncurses-dev flex \
        libsdl1.2-dev xterm sed cvs subversion coreutils texi2html docbook-utils tree cpio lz4 zstd \
        help2man make gcc g++ desktop-file-utils libgl1-mesa-dev libglu1-mesa-dev mercurial autoconf rsync \
        automake groff curl lzop asciidoc lib32z1 libssl-dev lib32ncurses-dev autoconf-archive bison kmod \
        iputils-ping python python3 python3-pip python3-pexpect python-pysqlite2 python3-git python3-jinja2 \
        kpartx jq binfmt-support qemu qemu-user-static debootstrap debian-archive-keyring cmake gcc-arm-none-eabi"

    apt update > /dev/null 2>&1
    apt install -y $systools
}

function install_crosstool()
{
    if command -v aarch64-linux-gnu-gcc > /dev/null 2>&1 ; then
        pr_info "All development tools already installed, skip it"
        return 0;
    fi

    pr_info "start apt install devlopment tools(commands)"

    devtools="u-boot-tools mtd-utils device-tree-compiler gcc-aarch64-linux-gnu \
        binfmt-support qemu qemu-user-static debootstrap debian-archive-keyring "

    apt install -y $devtools
}

echo ""

install_systools

install_crosstool

