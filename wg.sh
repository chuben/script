#!/bin/bash

# 参数检查
if [ -z "$1" ]; then
    echo "❌ 用法: $0 <解密密钥>"
    exit 1
fi

KEY="$1"

# 启用 IP 转发 + 禁用 IPv6
echo "net.ipv4.ip_forward=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1" > /etc/sysctl.conf
sysctl -p

# 添加 buster-backports（仅 Debian Buster）
if grep -q 'buster' /etc/os-release; then
    echo 'deb http://archive.debian.org/debian buster-backports main contrib non-free' >> /etc/apt/sources.list
fi

# 安装依赖
apt update -y
apt install wireguard resolvconf curl wget openssl -y

# 获取网卡和公网 IP 第四段
nic_name=$(ip route | grep default | head -1 | awk '{print $5}')
ip=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)
ip_last1=$(echo $ip|awk -F '.' '{print $3}')
ip_last2=$(echo $ip| awk -F '.' '{print $4}')

# 加密后的密钥（请替换为你自己的加密后值）
ENC_PRIVATE_KEY="U2FsdGVkX1/1da1pfoZqKVefnSF5doyWLCWMu5Jl5tufWLNmP5zQVxbsdW+KlhxX +mMJgjJMOEkL6O4IkK70WQ=="
ENC_PEER_PUB_KEY="U2FsdGVkX1/I4Vx+Oylxaqqi7V7UYQNY88uLAg08Aqj8wKZ9TJMGYc2MZ5G7dqRi Ih+xjqGBuZn/y/ZOjdko1g=="

# 解密
PRIVATE_KEY=$(echo "$ENC_PRIVATE_KEY" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$KEY")
PEER_PUB_KEY=$(echo "$ENC_PEER_PUB_KEY" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$KEY")

# 写入 WireGuard 配置
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.${ip_last1}.${ip_last2}.1/24,fe80:25bd:7d15:38b9::1/128
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $nic_name -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $nic_name -j MASQUERADE
ListenPort = 50${ip_last2}
DNS = 1.1.1.2,1.1.1.3
MTU = 1420

[Peer]
PublicKey = $PEER_PUB_KEY
AllowedIPs = 10.${ip_last1}.${ip_last2}.10/24,fe80:25bd:7d15:38b9::10/128
EOF

# 启动 WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo "✅ WireGuard 已成功安装并启动！"
