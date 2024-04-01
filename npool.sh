#!/bin/bash

if which apt >/dev/null; then
    apt update --allow-releaseinfo-change -y
    apt install wget curl unzip jq -y
elif which yum >/dev/null; then
    yum makecache -y
    yum install wget curl unzip jq -y
else
    echo -e "\033[31m不支持此系统\033[0m"
    exit 1
fi

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install"
    exit 1
fi

# Check appKey
app_key=$1
if [ ! -n "$app_key" ]; then
    echo "Error: missing appKey"
    exit 1
fi

s3url=$2
if [ ! -n "$s3url" ]; then
    echo "Error: missing db_url"
    exit 1
fi

# Check arch
get_arch=`arch`
if [[ $get_arch =~ "x86_64" ]];then
    arch_type="amd64"
elif [[ $get_arch =~ "aarch64" ]];then
    arch_type="arm64"
else
    echo "Error: Only supports amd64 and arm64 architecture machines"
    exit 1
fi

cur_dir='/opt/nginx'
mkdir -p $cur_dir >>/dev/null 2>&1
cd $cur_dir

# Stop
systemctl is-active --quiet nkn && systemctl stop --no-block nkn

# Download Package
function Download_npool()
{
    echo "Start Download......"
    wget -c -t 5 --quiet -O - "https://download.npool.io/linux-${arch_type}.tar.gz" | tar -zxf - -C /tmp
    cp -rf /tmp/linux-${arch_type}/npool $cur_dir/.
    cp -rf /tmp/linux-${arch_type}/config.json $cur_dir/.
    [ -f "$cur_dir/nknd" ] && rm -rf ${cur_dir}/nknd
}

function init_wallet(){
    [ -f "$cur_dir/wallet.json" ] && [ -f "$cur_dir/wallet.pswd" ] && return 0
    echo '{"Version":2,"IV":"e18377432ed1a73256a87bd634982702","MasterKey":"8ee290880b0a464c508ee44306d537f67013407ac265e2e06c0886638f0122ca","SeedEncrypted":"eb5be4d7ceb32cb18808b6d69563c2766a978dc633f19bc27f3fbb0a5ef31726","Address":"NKNW4kJJM6hDE6qwAFhg56dAffHFsXJgZxUM","Scrypt":{"Salt":"3fea2835d5e28141","N":32768,"R":8,"P":1}}' > $cur_dir/wallet.json
    echo '316gjddz2yfb88x+rj6z1pwbknkj7wou' > $cur_dir/wallet.pswd
}

function get_server_url() {
    site=''
    local_region=$(wget -t 3 -T 2 -qO- http://169.254.169.254/2021-03-23/dynamic/instance-identity/document | jq .region | xargs)
    if [ -z "$site" ]; then
        for s3 in `echo -e $s3url | grep "$local_region" | shuf`; do
            url="https://${s3}.amazonaws.com"
            code=$(curl -o /dev/null -L -s -w %{http_code} ${url}/releases.txt)
            [ "$code" -eq 200 ] && site=$url && break
        done
    fi

    if [ -z "$site" ]; then
        for s3 in `echo -e $s3url| grep -v "$local_region" | shuf`; do
            url="https://${s3}.amazonaws.com"
            code=$(curl -o /dev/null -L -s -w %{http_code} ${url}/releases.txt)
            [ "$code" -eq 200 ] && site=$url && break
        done
    fi
}

function download_db() {
    du -s ChainDB
    [ "$(du -s $cur_dir/ChainDB | awk '{print $1}')" -gt 4000000 ] && return 0
    [ -z "$s3url" ] && return 1
    [ ! -d "$cur_dir/tmp" ] && mkdir -p $cur_dir/tmp
    get_server_url
    [ -z "$site" ] && echo "db下载失败" && return 1
    rm -rf $cur_dir/tmp/ChainDB >>/dev/null 2>&1
    wget --no-check-certificate ${site}/ChainDB.tar.gz -qO - | tar -zxf - -C $cur_dir/tmp/
    [ "$?" -ne 0 ] && return 1

    if [ "$(du -s $cur_dir/tmp/ | awk '{print $1}')" -gt 4000000 ]; then
        systemctl is-active --quiet npool && systemctl stop --no-block npool
        rm -rf $cur_dir/ChainDB*
        mv -f $cur_dir/tmp/ChainDB $cur_dir/.
    else
        echo -e "\033[31mDownload failed, try again.\033[0m"
        killall -9 wget >>/dev/null 2>&1
        rm -rf $cur_dir/tmp/ChainDB >>/dev/null 2>&1
    fi
}

# Install
function Install_NPool()
{
    echo "Start Install......"
    ulimit -n 1000000
    echo "root  soft  nofile  10000000" >> /etc/security/limits.conf
    echo "ubuntu  soft  nofile  10000000" >> /etc/security/limits.conf
    echo "DefaultLimitNOFILE=10000000" >> /etc/systemd/user.conf
    echo "DefaultLimitNOFILE=10000000" >> /etc/systemd/system.conf
    start_shell="${cur_dir}/npool --appkey ${app_key} --wallet ${cur_dir}/wallet.json --password-file ${cur_dir}/wallet.pswd --pruning none --no-nat"
    cat > /etc/systemd/system/nkn.service <<End-of-file
[Unit]
Description=npool server

[Service]
Type=simple
WorkingDirectory=${cur_dir}
ExecStart=${start_shell}
Restart=always
RestartSec=20
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
End-of-file
    systemctl daemon-reload
    systemctl enable nkn.service
    systemctl start nkn.service
    echo "Success."
}

Download_npool
download_db
init_wallet
Install_NPool
