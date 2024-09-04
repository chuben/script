#!/bin/bash
net_version=$(bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh) --version )
script_version=$(/q/qli-Service.sh -v)
new_version=`echo -e "$net_version\n$script_version" |sort | tail -1`
if [ "$new_version" != "$script_version" ]; then
echo "开始更新脚本"
nohup bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/update.sh) >> ~/install.log &
else
echo "脚本无需更新 $script_version"
net_client_version="$(wget -T 3 -t 2 -qO- https://github.com/qubic-li/client/raw/main/README.md | grep '| Linux |' | awk -F '|' '{print $4}' | grep -v beta | tail -1 | xargs)"
local_client_version=$(/q/qli-Client --version|awk '{print $3}')
client_version=`echo -e "$local_client_version\n$net_client_version" |sort | tail -1`
if [ "$client_version" != "$local_client_version" ]; then
    echo "开始更新客户端"
    nohup bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/update.sh) >> ~/install.log &
else
    echo "客户端无需更新 $client_version"
fi
fi

version=`curl -sL https://github.com/ore-pool/ore-pool-cli/releases | grep 'ore-pool/ore-pool-cli/releases/tag' |awk '{print $7}' | xargs |awk '{print $1}' |awk -F '/' '{print $6}'`
localversion=`/opt/ore/ore-pool-cli --version |awk '{print $2}'`
newversion=`echo -e "$localversion\n$version" | sed "s/v//g"|sort |tail -1`
if [ "$localversion" != "$newversion" ]; then
    wget -O- https://raw.githubusercontent.com/chuben/script/main/ore.sh | bash
fi