#!/bin/bash

[ -f "/q/env" ] && source /q/env
[ -f "/q/.env" ] && source /q/.env
[ -f "/q/install.conf" ] && source /q/install.conf

[ -z "$accessToken" ] || [ -z "$minerAlias" ] || [ -z "$payoutId" ] || [ -z "$pushUrl" ] && exit

apt update -y && apt install wget jq curl -y

alias="$(echo $minerAlias | awk -F '-' '{print $1}'|awk -F '_' '{print $1}')"

country=$(wget -qO - http://ipinfo.io | jq .country | xargs )

bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh ) --access-token $accessToken --miner-alias ${alias}_${country}  --payout-id $payoutId --push-url $pushUrl --install

systemctl restart qli