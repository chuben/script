#!/bin/bash

payoutId=$1
ip=$(curl -sL ifconfig.me)
[ "$2" ] && minerAlias="$2_$ip" || minerAlias=$ip

threads=`nproc`
[ "$threads" -gt 8 ] && threads=$(expr `nproc` \* 8 / 10)

[ -z "$payoutId" ] && exit
[ -z "$minerAlias" ] && exit

path='/zoxx'

case $(uname -m) in
armv5*) ARCH="aarch64" ;;
armv6*) ARCH="aarch64" ;;
armv7*) ARCH="aarch64" ;;
aarch64) ARCH="aarch64" ;;
x86) ARCH="x86" ;;
x86_64) ARCH="x86" ;;
i686) ARCH="x86" ;;
i386) ARCH="x86" ;;
*) echo -e "\033[31m不支持此系统\033[0m" && exit 1 ;;
esac
apt update -y && apt install curl -y
#stop service if it is running
systemctl is-active --quiet qli && systemctl stop --no-block qli
file_name="rqiner-${ARCH}"
version=$(curl -sL  https://github.com/Qubic-Solutions/rqiner-builds/releases | grep 'Qubic-Solutions/rqiner-builds/releases/tag'| head -1|awk '{print $7}'|xargs|awk -F '/' '{print $6}')
#install
[ ! -d "$path" ] && mkdir $path 
[ -f "$path/$file_name" ] && rm -rf $path/$file_name
cd $path 
curl -o $path/$file_name -sL https://github.com/Qubic-Solutions/rqiner-builds/releases/download/${version}/${file_name}
chmod u+x $path/$file_name
echo """
[Unit]
After=network-online.target
[Service]
StandardOutput=append:/var/log/zoxx.log
StandardError=append:/var/log/zoxx.log
ExecStart=$path/$file_name -t $threads -l $minerAlias -i $payoutId
Restart=on-failure
RestartSec=1s
[Install]
WantedBy=default.target
""" > /etc/systemd/system/zoxx.service
chmod 664 /etc/systemd/system/zoxx.service
systemctl daemon-reload
systemctl enable --no-block zoxx.service
systemctl start --no-block zoxx.service
sleep 10
tail -20 /var/log/zoxx.log