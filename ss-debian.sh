#!/bin/bash

[ "$1" ] && pwd="$1" || exit 1

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

apt update && apt install -y wget

bash <(wget -qO- https://git.io/v2ray.sh)

v2ray del *

v2ray add ss 8388 $pwd aes-256-gcm