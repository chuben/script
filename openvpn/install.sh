#!/bin/bash
set -e

# ===== 配置区 =====
VPN_NET="10.10.0.0"
VPN_MASK="255.255.255.0"
VPN_GW="10.10.0.1"
VPN_START="10.10.0.50"
VPN_END="10.10.0.100"
VPN_PORT=8443
VPN_PROTO="tcp"

BR_IF="br0"
TAP_IF="tap"
CONF_DIR="/etc/openvpn"
SERVER_CONF="$CONF_DIR/server.conf"
UP_SCRIPT="$CONF_DIR/up.sh"
DOWN_SCRIPT="$CONF_DIR/down.sh"

# ===== 安装依赖 =====
apt update
apt install -y --no-install-recommends  openvpn bridge-utils openssl ca-certificates age

# ===== 创建 br0 桥 =====
if ! ip link show $BR_IF &>/dev/null; then
    echo "[*] 创建网桥 $BR_IF"
    ip link add name $BR_IF type bridge
    ip addr add $VPN_GW/24 dev $BR_IF
    ip link set dev $BR_IF up
else
    echo "[*] 网桥 $BR_IF 已存在"
fi

# ===== 生成 up.sh =====
cat > $UP_SCRIPT <<EOF
#!/bin/bash
BR="$BR_IF"
TAP="\$1"
# ===== 创建 br0 桥 =====
if ! ip link show \$BR &>/dev/null; then
    echo "[*] 创建网桥 \$BR"
    ip link add name \$BR type bridge
    ip addr add $VPN_GW/24 dev \$BR
    ip link set dev \$BR up
else
    echo "[*] 网桥 \$BR 已存在"
fi

ip link set \$TAP up
ip link set \$TAP master \$BR
EOF

chmod +x $UP_SCRIPT

# ===== 生成 down.sh =====
cat > $DOWN_SCRIPT <<EOF
#!/bin/bash
BR="$BR_IF"
TAP="\$1"
ip link set \$TAP nomaster
ip link set \$TAP down
EOF

chmod +x $DOWN_SCRIPT



wget -qO /tmp/conf.tar.gz.age "https://raw.githubusercontent.com/chuben/script/main/openvpn/conf.age"

ENC_AGE_SECRET_KEY="U2FsdGVkX1/kGblucAIThGngTkQrDOKJ5Zk5WhnJLbZ8sD63Z7vYkB/eLRQ/EDEk 99Pk1qZRb8de4oKRZ3+i1uLXgo1MlSrx09h32vpZRF75KGquHFn9uBAOA+qrjpe1"
AGE_SECRET_KEY=$(echo "$ENC_AGE_SECRET_KEY" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$KEY")

age -d -i <(echo "$AGE_SECRET_KEY") /tmp/conf.tar.gz.age | tar xz -C /etc/openvpn --strip-components=1

chown nobody:"$group_name" /etc/openvpn/crl.pem
chmod o+x /etc/openvpn/

# ===== 生成 server.conf =====
cat > $SERVER_CONF <<EOF
port $VPN_PORT
proto $VPN_PROTO
dev $TAP_IF

ca ca.crt
cert server.crt
key server.key
dh dh.pem

auth SHA512
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-CBC
tls-crypt tc.key

mode server
server-bridge $VPN_GW $VPN_MASK $VPN_START $VPN_END

keepalive 10 120
persist-key
persist-tun
user nobody
group nogroup
verb 3
crl-verify crl.pem

script-security 2
up "$UP_SCRIPT"
down "$DOWN_SCRIPT"

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

iptables -t nat -A POSTROUTING -s $VPN_NET/$VPN_MASK -o $WAN_IF -j MASQUERADE


systemctl restart openvpn-server@server.service 