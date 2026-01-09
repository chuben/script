#!/bin/bash

[ "$1" ] && KEY="$1" || exit 1

echo """
######## Windows-like TCP profile ########

# TTL 与 Windows 对齐
net.ipv4.ip_default_ttl=128

# Windows 默认关闭 timestamps
net.ipv4.tcp_timestamps=0

# 启用 SACK（Windows 默认）
net.ipv4.tcp_sack=1

# 启用窗口缩放
net.ipv4.tcp_window_scaling=1

# 使用 CUBIC（Windows 10+）
net.ipv4.tcp_congestion_control=cubic

# 常见 Windows 窗口范围
net.ipv4.tcp_rmem=4096 87380 6291456
net.ipv4.tcp_wmem=4096 65536 6291456

# 避免异常 MTU 行为
net.ipv4.tcp_mtu_probing=1

########################################
""" > /etc/sysctl.conf
sysctl -p

apt update && apt install -y wget age

bash <(wget -qO- https://git.io/v2ray.sh)

rm -rf /etc/v2ray/conf/*

wget -qO /tmp/ss.json.age "https://raw.githubusercontent.com/chuben/script/main/ss.json.age"

ENC_AGE_SECRET_KEY="U2FsdGVkX1/kGblucAIThGngTkQrDOKJ5Zk5WhnJLbZ8sD63Z7vYkB/eLRQ/EDEk 99Pk1qZRb8de4oKRZ3+i1uLXgo1MlSrx09h32vpZRF75KGquHFn9uBAOA+qrjpe1"
AGE_SECRET_KEY=$(echo "$ENC_AGE_SECRET_KEY" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$KEY")

age -d -i <(echo "$AGE_SECRET_KEY") /tmp/ss.json.age > /etc/v2ray/conf/Shadowsocks-8388.json 

v2ray restart