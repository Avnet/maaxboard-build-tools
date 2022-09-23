#!/bin/bash

if [ -z $TOOLS_PATH ] ; then
    echo "please source source.sh first"
    exit 1
fi

# display in red
function pr_error() {
    echo -e "\033[40;31m --E-- $1 \033[0m\n"
}

# display in yellow
function pr_warn() {
    echo -e "\033[40;33m --W-- $1 \033[0m\n"
}

# display in green
function pr_info() {
    echo -e "\033[40;32m --I-- $1 \033[0m\n"
}

function jq_check()
{
    if [[ -z $1 || $1 == null ]] ;then
        return 1;
    fi
}

do_fetch_git()
{
    node=$1

    # parser git server
    git_server=`jq -r .git.server $CONF_FILE`
    git_uid=`jq -r .git.username $CONF_FILE`
    git_pwd=`jq -r .git.password $CONF_FILE`

    # add username and password to git server URL if needed
    if echo $git_server | grep "http" > /dev/null 2>&1 ; then
        if jq_check $git_uid && jq_check $git_pwd ; then
            git_server=`echo $git_server | sed "s|://|://$git_uid:$git_pwd@|g"`
        fi
    fi

    # parser git options
    git_option=`jq -r .git.option $CONF_FILE`

    # parser git repository url, use name if url not exist.
    git_url=`jq -r --arg v "$node" '.[$v].url' $CONF_FILE`
    if ! jq_check $git_url ; then
        git_name=`jq -r --arg v "$node" '.[$v].name' $CONF_FILE`
        if jq_check $git_name ; then
            git_url=$git_server/$git_name
        fi
    fi

    if ! jq_check $git_url ; then
        pr_error "no git url configured for $node"
        return 1;
    fi

    # parser option
    node_opt=`jq -r --arg v "$node" '.[$v].option' $CONF_FILE`
    if jq_check $node_opt ; then
        git_option+=" $node_opt";
    fi

    git_branch=`jq -r --arg v "$node" '.[$v].branch' $CONF_FILE`
    git_branch=`eval echo $git_branch`

    if jq_check $git_branch ; then
        git_option+=" -b $git_branch";
    fi

    # start git clone
    cmd="git clone $git_option $git_url"
    echo $cmd && sh -c "$cmd"
}

do_fetch_firmware()
{
    node="firmware"

    url=`jq -r .$node.url $CONF_FILE`
    files=`jq -r .$node.files $CONF_FILE`

    if ! jq_check $url ; then
        pr_error "no git url configured for $node"
        return 1;
    fi

    mkdir -p firmware/bins

    cd firmware

    for f in $files
    do
        if [ ! -s bins/$f ] ; then
            wget $url/$f -P bins
        fi

        dir=`echo $f | awk -F".bin" '{print $1}'`
        if [ ! -d $dir ] ; then
            bash bins/$f --auto-accept > /dev/null 2>&1
        fi
    done
}


# decompress a packet to destination path
function do_unpack() {
    tarball=$1
    dstpath=`pwd`

    if [[ $# == 2 ]] ; then
        dstpath=$2
    fi

    pr_info "decompress $tarball => $dstpath"

    mkdir -p $dstpath
    case $tarball in
        *.tar.gz)
            tar -xzf $tarball -C $dstpath
            ;;

        *.tar.bz2)
            tar -xjf $tarball -C $dstpath
            ;;

        *.tar.xz)
            tar -xJf $tarball -C $dstpath
            ;;

        *.tar)
            tar -xf $tarball -C $dstpath
            ;;

        *.zip)
            unzip -qo $tarball -d $dstpath
            ;;

        *)
            pr_error "decompress Unsupport packet: $tarball"
            return 1;
            ;;
    esac
}

