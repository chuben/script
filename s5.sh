#!/bin/bash

bash <(wget -qO- https://git.io/v2ray.sh)

apt update && apt install -y bc wget

ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"

[ "$ip" ] && port=$(echo "5000 + $(echo $ip | awk -F '.' '{print $4}')" | bc) || port=5000

[ "$1" ] && pwd="$1" || pwd="bd2de253d21979799315004c01801df0"

v2ray add socks $port svip $pwd