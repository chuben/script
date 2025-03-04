#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行该脚本。"
  exit
fi

# 更新系统并安装 Unbound
apt update && apt install -y unbound wget

# 停止 Unbound 服务以进行配置
systemctl stop unbound

# 下载最新的根提示文件
wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
chown unbound:unbound /var/lib/unbound/root.hints

# 生成 DNSSEC 信任锚文件
unbound-anchor -a /var/lib/unbound/root.key
chown unbound:unbound /var/lib/unbound/root.key

# 备份原有的配置文件
mv /etc/unbound/unbound.conf /etc/unbound/unbound.conf.backup

# 创建新的 Unbound 配置文件
cat > /etc/unbound/unbound.conf <<EOF
server:
    interface: 0.0.0.0
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    access-control: 0.0.0.0/0 allow
    access-control: 127.0.0.0/8 allow
    access-control: 192.168.0.0/16 allow
    access-control: 10.0.0.0/8 allow
    use-syslog: yes
    verbosity: 1
    root-hints: "/var/lib/unbound/root.hints"
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    harden-below-nxdomain: yes
    qname-minimisation: yes
    cache-min-ttl: 0
    cache-max-ttl: 0
    prefetch: no
    serve-expired: no
    msg-cache-size: 0
    rrset-cache-size: 0
    neg-cache-size: 0
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
EOF

systemctl disable systemd-resolved
systemctl stop systemd-resolved
# 启用并启动 Unbound 服务
systemctl enable unbound
systemctl start unbound

echo 'nameserver 127.0.0.1' >> /etc/resolv.conf
echo "Unbound 已成功安装并配置为严格递归查询且无缓存的 DNS 服务器。"
