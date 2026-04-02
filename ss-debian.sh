#!/bin/bash

[ "$1" ] && KEY="$1" || exit 1

systemctl stop ss-rust shadow-tls && systemctl disable ss-rust shadow-tls

bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)

sing-box del *

sing-box add Trojan 443 "$KEY"