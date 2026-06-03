#!/bin/bash
set -e

########################################
# 参数检查
########################################

[ -z "$1" ] && {
    echo "Usage: $0 <sstp_password>"
    exit 1
}

PSW="$1"
SUBNET_ID=$((RANDOM % 254 + 1))
SUBNET="172.16.${SUBNET_ID}.0/24"
GATEWAY="172.16.${SUBNET_ID}.1"

export DEBIAN_FRONTEND=noninteractive

########################################
# iptables-persistent 预设
########################################

echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

########################################
# 安装系统组件
########################################

apt update

if uname -r | grep -q cloud; then
    echo "Cloud kernel detected, installing standard kernel..."

    apt install -y \
        linux-image-amd64 \
        linux-headers-amd64

    rm -rf /boot/*-cloud-*

    update-grub

    echo "Kernel switched. Reboot required."
fi

apt install -y \
    iptables-persistent \
    netfilter-persistent \
    net-tools \
    curl \
    ppp \
    openssl


########################################
# PPP 配置
########################################

cat >/etc/ppp/options.sstpd <<EOF
name sstpd
require-mschap-v2
nologfd
nodefaultroute
ms-dns 1.1.1.1
EOF

cat >/etc/ppp/chap-secrets <<EOF
# client server secret IP
m * ${PSW} *
EOF

########################################
# 安装 Micromamba
########################################

curl -Ls https://micro.mamba.pm/install.sh | bash

export MAMBA_ROOT_PREFIX=/root/micromamba
eval "$(/root/.local/bin/micromamba shell hook -s bash)"

micromamba create -y -n py39 python=3.9

########################################
# 安装 SSTP Server
########################################

micromamba run -n py39 pip install -U pip
micromamba run -n py39 pip install sstp-server

mkdir -p /opt/sstp
cd /opt/sstp

########################################
# 生成自签名证书
########################################

openssl req \
    -x509 \
    -newkey rsa:4096 \
    -sha256 \
    -days 3650 \
    -nodes \
    -keyout privkey.pem \
    -out fullchain.pem \
    -subj "/C=SG/ST=Singapore/L=Singapore/O=SSTP/CN=$(hostname -f)"

chmod 600 privkey.pem

########################################
# 开启转发
########################################

cat >/etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF

sysctl -p

########################################
# NAT
########################################

WAN_IF=$(ip route | awk '/default/ {print $5; exit}')
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING \
    -s ${SUBNET} \
    -o ${WAN_IF} \
    -j MASQUERADE

netfilter-persistent save

########################################
# 启动脚本
########################################

cat >/opt/sstp/start.sh <<EOF
#!/bin/bash

export MAMBA_ROOT_PREFIX=/root/micromamba
eval "\$(/root/.local/bin/micromamba shell hook -s bash)"

micromamba activate py39

exec /root/micromamba/envs/py39/bin/sstpd \
    -c /opt/sstp/fullchain.pem \
    -k /opt/sstp/privkey.pem \
    --local ${GATEWAY} \
    --remote ${SUBNET} \
    -p 9443 \
    -l 0.0.0.0
EOF

chmod +x /opt/sstp/start.sh

########################################
# systemd
########################################

cat >/etc/systemd/system/sstp.service <<EOF
[Unit]
Description=SSTP Server
After=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/sstp
ExecStart=/opt/sstp/start.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sstp

echo
echo "======================================"
echo "SSTP 安装完成"
echo "监听端口: 9443"
echo "用户名: m"
echo "密码: ${PSW}"
echo "======================================"
echo

reboot