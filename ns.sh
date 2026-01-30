#!/usr/bin/env bash
set -e

# ===== 参数检查 =====
if [ -z "$1" ]; then
  echo "Usage: $0 example.com"
  exit 1
fi

domain="$1"

# ===== 安装 bind =====
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y bind9 bind9utils curl

# ===== 获取公网 IP =====
ip="$(curl -4fsSL https://ifconfig.me)"
if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Failed to get public IPv4 address"
  exit 1
fi

echo "[+] Domain: $domain"
echo "[+] Public IP: $ip"

# ===== 目录准备 =====
mkdir -p /etc/bind/zones

# ===== named.conf.local（幂等写入）=====
if ! grep -q "zone \"$domain\"" /etc/bind/named.conf.local 2>/dev/null; then
cat >> /etc/bind/named.conf.local <<EOF

zone "$domain" {
  type master;
  file "/etc/bind/zones/$domain.zone";
};
EOF
fi

# ===== SOA Serial（YYYYMMDDNN）=====
serial="$(date +%Y%m%d)01"

# ===== zone 文件 =====
cat > /etc/bind/zones/$domain.zone <<EOF
\$TTL 300
@   IN SOA ns1.$domain. admin.$domain. (
        $serial
        300
        300
        1209600
        300 )

@   IN NS  ns1.$domain.
ns1 IN A   $ip

@   IN A   $ip
*   IN A   $ip

@   IN MX 10 mail.$domain.
mail IN A $ip

@   IN TXT "v=spf1 ip4:$ip ~all"
EOF

# ===== 校验 =====
named-checkzone "$domain" "/etc/bind/zones/$domain.zone"

# ===== 重载 =====
systemctl restart bind9

echo "[✓] BIND authoritative DNS for $domain is ready"
