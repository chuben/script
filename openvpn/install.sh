#!/bin/bash
set -e

[ -z "$1" ] && exit || KEY=$1


BR_IF="br0"
CONF_DIR="/etc/openvpn/server"
SERVER_CONF="$CONF_DIR/server.conf"

# ===== 安装依赖 =====
export DEBIAN_FRONTEND=noninteractive
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

apt update
apt install -y --no-install-recommends  openvpn openssl age netfilter-persistent iptables-persistent

wget -qO /tmp/conf.tar.gz.age "https://raw.githubusercontent.com/chuben/script/main/openvpn/conf.age"

ENC_AGE_SECRET_KEY="U2FsdGVkX1/kGblucAIThGngTkQrDOKJ5Zk5WhnJLbZ8sD63Z7vYkB/eLRQ/EDEk 99Pk1qZRb8de4oKRZ3+i1uLXgo1MlSrx09h32vpZRF75KGquHFn9uBAOA+qrjpe1"
AGE_SECRET_KEY=$(echo "$ENC_AGE_SECRET_KEY" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$KEY")

age -d -i <(echo "$AGE_SECRET_KEY") /tmp/conf.tar.gz.age | tar xz -C /etc/openvpn

chown nobody:nogroup "$CONF_DIR/crl.pem"
chmod o+x "$CONF_DIR"

# ===== 生成 server.conf =====
cat > $SERVER_CONF <<EOF
port 8443
proto tcp
dev tun

ca ca.crt
cert server.crt
key server.key
dh dh.pem

auth SHA512
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-CBC
tls-crypt tc.key

mode server
server 10.8.0.0 255.255.255.0

keepalive 10 120
persist-key
persist-tun
user nobody
group nogroup
verb 3
crl-verify crl.pem

push "redirect-gateway def1"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
EOF


# ===== 开启 IP 转发 =====
echo "[*] 启用内核 IP 转发"
sysctl -w net.ipv4.ip_forward=1
sed -i '/^net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# ===== 设置 NAT (MASQUERADE) =====
WAN_IF=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
echo "[*] 出口网卡检测到: $WAN_IF"

iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $WAN_IF -j MASQUERADE

systemctl daemon-reload
systemctl enable openvpn-server@server.service 
systemctl restart openvpn-server@server.service 
netfilter-persistent save