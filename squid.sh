#!/bin/bash

apt-get install -y squid

# 备份原始配置文件
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# 创建新的配置文件
cat << EOF | tee /etc/squid/squid.conf
# 基本配置
http_port 29999
http_access allow all
dns_nameservers 1.1.1.1
cache_dir ufs /var/spool/squid 100 16 256
coredump_dir /var/spool/squid
EOF

# 重启Squid服务以应用配置
systemctl restart squid

# 设置Squid开机自启
systemctl enable squid