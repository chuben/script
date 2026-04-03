#!/bin/bash

[ "$1" ] && KEY="$1" || exit 1

bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)

sb del *

sb add ss 443 "$KEY" "aes-256-gcm"