#!/bin/bash

[ "$1" ] && KEY="$1" || exit 1

bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)

rm -rf /etc/sing-box/conf/*

sing-box restart

sb add trojan 443 $KEY