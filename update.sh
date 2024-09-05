#!/bin/bash

[ -f "/q/env" ] && source /q/env
[ -f "/q/.env" ] && source /q/.env
[ -f "/q/install.conf" ] && source /q/install.conf

[ -z "$accessToken" ] || [ -z "$minerAlias" ] || [ -z "$payoutId" ] && exit

apt update -y && apt install wget jq curl -y

alias="$(echo $minerAlias | awk -F '-' '{print $1}'|awk -F '_' '{print $1}')"

country=$(wget -qO - http://ipinfo.io | jq .country | xargs )

instype=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/instance-type| sed "s/xlarge//g"|sed "s/\.//g")

tag="${alias}_${instype}_${country}"

bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh ) --access-token $accessToken --miner-alias $tag  --payout-id $payoutId --install

systemctl restart qli