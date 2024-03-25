#!/bin/bash

help_info=" Usage:\n\tbash $(basename $0)\t-s/--server-domain [\033[33m\033[04m服务器域名\033[0m]\n\t\t\t-d/--dir [\033[04m安装目录\033[0m]\n"

local_region=$(wget -t 3 -T 2 -qO- http://169.254.169.254/2021-03-23/dynamic/instance-identity/document | jq .region | xargs)

function get_server_url() {
    site=''
    if [ "$serverip" ]
    then
        url="http://${serverip}:5288"
        i=0
        while [ $i -lt 180 ]; do
            let i++
            echo "第 $i 次检查 $url"
            code=$(curl -o /dev/null -L -s -w %{http_code} ${url}/releases.txt)
            [ "$code" -eq 200 ] && site=$url && break
            sleep 10
        done
    fi

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

function check_version() {
    remote_version="$(curl -sL ${site}/releases.txt)"
    local_version="$($DIR/nknd -v | awk '{print $3}')"
    if [ $remote_version ]; then
        if [ "$local_version" = "$remote_version" ]; then
            echo "No updates found."
        else
            echo "Discover the new version and update it automatically."
            download_new_version
        fi
    else
        echo -e "\033[31mUnable to obtain version information.\033[0m"
    fi
}

function download_new_version() {
    echo "下载新版本"
    rm -rf /tmp/linux*
    wget --no-check-certificate -qO /tmp/linux-$ARCH.zip ${site}/linux-$ARCH.zip
    unzip -q /tmp/linux-$ARCH.zip -d /tmp
    [ "$?" -eq 0 ] && install_nknorg
}

function install_nknorg() {
    echo "开始安装."
    if [ ! -f "/tmp/linux-${ARCH}/nknd" ] || [ "$(/tmp/linux-${ARCH}/nknd -v | awk '{print $3}')" == "$local_version" ]; then
        echo -e "\033[31m$(date +%F" "%T) Update failed\033[0m"
    else
        kill $(pgrep nknd) >>/dev/null 2>&1
        cp -rf /tmp/linux-$ARCH/* $DIR/.
        chmod +x $DIR/nkn*
    fi
    systemctl restart nkn
}

function check_status() {
    if [ ! $(pgrep nknd) ]; then
        check_file
        $DIR/nknd --no-nat --password-file=wallet.pswd >>/dev/null 2>&1 &
    fi
    if [ $i -gt 120000 ]; then
        i=0
        get_server_url
        [ -z "$site" ] && i=100000 && break
        check_version
    else
        let i++
    fi
}

function init_wallet(){
    echo '{"Version":2,"IV":"e18377432ed1a73256a87bd634982702","MasterKey":"8ee290880b0a464c508ee44306d537f67013407ac265e2e06c0886638f0122ca","SeedEncrypted":"eb5be4d7ceb32cb18808b6d69563c2766a978dc633f19bc27f3fbb0a5ef31726","Address":"NKNW4kJJM6hDE6qwAFhg56dAffHFsXJgZxUM","Scrypt":{"Salt":"3fea2835d5e28141","N":32768,"R":8,"P":1}}' > $DIR/wallet.json
    echo '316gjddz2yfb88x+rj6z1pwbknkj7wou' > $DIR/wallet.pswd
}

function init_config(){
    echo '{"BeneficiaryAddr":"NKNDGWGgC6Voe9z6HNJbbAPURfWo3ha5jBen","LogLevel":3,"SyncMode":"light","StatePruningMode":"none","SeedList":["http://mainnet-seed-0001.nkn.org:30003","http://mainnet-seed-0002.nkn.org:30003","http://mainnet-seed-0003.nkn.org:30003","http://mainnet-seed-0004.nkn.org:30003","http://mainnet-seed-0005.nkn.org:30003","http://mainnet-seed-0006.nkn.org:30003","http://mainnet-seed-0007.nkn.org:30003","http://mainnet-seed-0008.nkn.org:30003","http://mainnet-seed-0009.nkn.org:30003","http://mainnet-seed-0010.nkn.org:30003","http://mainnet-seed-0011.nkn.org:30003","http://mainnet-seed-0012.nkn.org:30003","http://mainnet-seed-0013.nkn.org:30003","http://mainnet-seed-0014.nkn.org:30003","http://mainnet-seed-0015.nkn.org:30003","http://mainnet-seed-0016.nkn.org:30003","http://mainnet-seed-0017.nkn.org:30003","http://mainnet-seed-0018.nkn.org:30003","http://mainnet-seed-0019.nkn.org:30003","http://mainnet-seed-0020.nkn.org:30003","http://mainnet-seed-0021.nkn.org:30003","http://mainnet-seed-0022.nkn.org:30003","http://mainnet-seed-0023.nkn.org:30003","http://mainnet-seed-0024.nkn.org:30003","http://mainnet-seed-0025.nkn.org:30003","http://mainnet-seed-0026.nkn.org:30003","http://mainnet-seed-0027.nkn.org:30003","http://mainnet-seed-0028.nkn.org:30003","http://mainnet-seed-0029.nkn.org:30003","http://mainnet-seed-0030.nkn.org:30003","http://mainnet-seed-0031.nkn.org:30003","http://mainnet-seed-0032.nkn.org:30003","http://mainnet-seed-0033.nkn.org:30003","http://mainnet-seed-0034.nkn.org:30003","http://mainnet-seed-0035.nkn.org:30003","http://mainnet-seed-0036.nkn.org:30003","http://mainnet-seed-0037.nkn.org:30003","http://mainnet-seed-0038.nkn.org:30003","http://mainnet-seed-0039.nkn.org:30003","http://mainnet-seed-0040.nkn.org:30003","http://mainnet-seed-0041.nkn.org:30003","http://mainnet-seed-0042.nkn.org:30003","http://mainnet-seed-0043.nkn.org:30003","http://mainnet-seed-0044.nkn.org:30003"],"GenesisBlockProposer":"a0309f8280ca86687a30ca86556113a253762e40eb884fc6063cad2b1ebd7de5"}' > $DIR/config.json
}

function check_file() {
    [ ! -f "$DIR/nknd" ] && get_server_url && check_version
    [ ! -f "$DIR/config.json" ] && init_config
    [ ! -f "$DIR/wallet.json" ] && init_wallet
    [ ! -f "$DIR/wallet.pswd" ] && init_wallet
}

function download_db() {
    [ ! -d "$DIR/tmp" ] && mkdir -p $DIR/tmp
    get_server_url
    [ -z "$site" ] && echo "db下载失败" && return 1
    rm -rf $DIR/tmp/ChainDB >>/dev/null 2>&1
    wget --no-check-certificate ${site}/ChainDB.tar.gz -qO - | tar -zxf - -C $DIR/tmp/
    [ "$?" -ne 0 ] && return 1

    if [ "$(du -s $DIR/tmp/ | awk '{print $1}')" -gt 4000000 ]; then
        kill $(pgrep nknd) >>/dev/null 2>&1
        rm -rf $DIR/ChainDB*
        mv -f $DIR/tmp/ChainDB $DIR/.
    else
        echo -e "\033[31mDownload failed, try again.\033[0m"
        killall -9 wget >>/dev/null 2>&1
        rm -rf $DIR/tmp/ChainDB >>/dev/null 2>&1
    fi
}

function install() {
    set -e
    case $(uname -m) in
    armv5*) ARCH="arm" ;;
    armv6*) ARCH="arm" ;;
    armv7*) ARCH="arm" ;;
    aarch64) ARCH="arm64" ;;
    x86) ARCH="386" ;;
    x86_64) ARCH="amd64" ;;
    i686) ARCH="386" ;;
    i386) ARCH="386" ;;
    *) echo -e "\033[31m不支持此系统\033[0m" && exit 1 ;;
    esac
    [ -z "$DIR" ] && echo -ne $help_info && exit 1
    [ -z "$DOMAIN" ] && echo -ne $help_info && exit 1
    mkdir -p $DIR/tmp
    echo -e "DIR=$DIR\nDOMAIN=$DOMAIN\nARCH=$ARCH\ndb_download_sw=$db_download_sw" > $DIR/.env
    echo "s3url='$s3url'" >> $DIR/.env

    mkdir -p /root/.ssh
    echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzc1dvKGnxJg2JxYu1LwfsaN+qHVeZpjXd5fJEs0PA9e+A/pwxD3AOgrpijbjVY/bQEm7y+cG6eVFol5IBrgglXACZY3Ru2YUtuQl0fRzSWoJyClPzEsyjiKzwRM7LYLSZYBolZIWgWw5mMWT6wyAWX5ffTOt+HvWiyFVssIFtjFVe4jJCA5ClDDDR1KvEQ/S3/C8McWksaV9rmqivhguUIRMiLMzAj3CIRlA0KgQfUV/I1hoJBXXCdqA3ERmfU0Eh6/Xr7vdZ8WijenUflMElSZqWVOGHwjHXdkZCQWwP19dckbelGfPlAgVZXjwD2RPglgH7kck9evYGSvaEMxZL root@debian' > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh/authorized_keys
    chown -R root:root /root/.ssh/authorized_keys
    echo root:$(openssl rand -base64 32 | cut -c 1-16) | chpasswd
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
    echo "ClientAliveInterval 60" >>/etc/ssh/sshd_config
    echo "ClientAliveCountMax 500" >>/etc/ssh/sshd_config

    if which apt >/dev/null; then
        apt update --allow-releaseinfo-change -y >>/dev/null 2>&1
        apt install wget curl unzip jq -y >>/dev/null 2>&1
    elif which yum >/dev/null; then
        yum makecache -y >>/dev/null 2>&1
        yum install wget curl unzip jq -y >>/dev/null 2>&1
    else
        echo -e "\033[31m不支持此系统\033[0m"
        exit 1
    fi
    cp $0 $DIR/monitor.sh
    chmod +x $DIR/monitor.sh
    [ "$http_server" == 'true' ] && cd $DIR && wget https://raw.githubusercontent.com/chuben/script/main/tgmd.py && nohup python3 ./tgmd.py &
    echo """[Unit]
    Description=NKNorg
    DefaultDependencies=no
    After=network.target

    [Service]
    Type=simple
    User=root
    EnvironmentFile=$DIR/.env
    WorkingDirectory=$DIR
    ExecStart=$DIR/monitor.sh
    Restart=always
    RestartSec=5s
    [Install]
    WantedBy=default.target""" > /etc/systemd/system/nkn.service

    systemctl daemon-reload
    systemctl enable nkn
    systemctl start nkn
    exit 0

}

function is_server(){
    
    site=''

    for s3 in `echo -e $s3url | grep "$local_region" | shuf`; do
        url="https://${s3}.amazonaws.com"
        code=$(curl -o /dev/null -L -s -w %{http_code} ${url}/releases.txt)
        [ "$code" -eq 200 ] && site=$url && break
    done

    if [ -z "$site" ]; then
        for s3 in `echo -e $s3url| grep -v "$local_region" | shuf`; do
            url="https://${s3}.amazonaws.com"
            code=$(curl -o /dev/null -L -s -w %{http_code} ${url}/releases.txt)
            [ "$code" -eq 200 ] && site=$url && break
        done
    fi

    [ -z "$site" ] && is_server
    
    mkdir -p /opt/www >>/dev/null 2>&1

    [ ! -f "/opt/www/linux-amd64.zip" ] && wget --no-check-certificate ${site}/linux-amd64.zip -O /opt/www/linux-amd64.zip
    [ "$?" -ne 0 ] && rm -rf /opt/www/linux-amd64.zip && is_server

    [ ! -f "/opt/www/linux-arm64.zip" ] && wget --no-check-certificate ${site}/linux-arm64.zip -O /opt/www/linux-arm64.zip 
    [ "$?" -ne 0 ] && rm -rf /opt/www/linux-arm64.zip && is_server

    [ ! -f "/opt/www/releases.txt" ] && wget --no-check-certificate ${site}/releases.txt -O /opt/www/releases.txt
    [ "$?" -ne 0 ] && rm -rf /opt/www/releases.txt && is_server

    [ ! -f "/opt/www/ChainDB.tar.gz" ] && wget --no-check-certificate ${site}/ChainDB.tar.gz -O /opt/www/ChainDB.tar.gz
    [ "$?" -ne 0 ] && rm -rf /opt/www/ChainDB.tar.gz && is_server

    nohup python3 -m http.server 5288 -d /opt/www >>/dev/null 2>&1

}

while [[ $# -ge 1 ]]; do
  case $1 in
    -s|--server-domain)
      shift
      DOMAIN="$1"
      shift
      ;;
    -d|--dir)
      shift
      DIR="$1"
      shift
      ;;
    -s3|--s3-url)
      shift
      s3url="$1"
      shift
      ;;
    -h|--http_server)
      shift
      http_server=true
      ;;
    -db|--download_db)
      shift
      db_download_sw=true
      ;;
    *)
      if [[ "$1" != 'error' ]]; then echo -ne "\nInvaild option: '$1'\n\n"; fi
      echo -ne $help_info
      exit 1;
      ;;
    esac
  done

[ -z "$DOMAIN" ] || [ -z "$ARCH" ] || [ -z "$DIR" ] || [ -z "$db_download_sw" ] || [ -z "$s3url" ] && source .env  >>/dev/null 2>&1

[ -z "$DOMAIN" ] || [ -z "$ARCH" ] || [ -z "$DIR" ] || [ -z "$s3url" ] && install

# 等待选举
while [ -z "$is_server" ] && [ "$http_server" == 'true' ]; do
    sleep 30
    source $DIR/.env
done

[ "$is_server" == "true" ] && [ ! "$(ps au| grep http.server | grep -v grep)" ] && is_server

echo $db_download_sw

[ "$db_download_sw" == "true" ] && [ "$(du -s $DIR | awk '{print $1}')" -lt 3500000 ] && download_db 

i=0
while true; do
    check_status
    sleep 5s
done