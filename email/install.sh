#!/bin/bash

echo "[+] 安装必要组件..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y exim4 mailutils curl wget

echo "[+] 设置 Exim4 为 non-split 配置..."
echo 'dc_eximconfig_configtype="internet"
dc_other_hostnames=""
dc_local_interfaces="127.0.0.1 ; 0.0.0.0"
dc_readhost=""
dc_relay_domains=""
dc_minimaldns="false"
dc_relay_nets=""
dc_smarthost=""
CFILEMODE=644
dc_use_split_config=false
dc_hide_mailname=true
dc_mailname_in_oh=true
dc_localdelivery="mail_spool"' > /etc/exim4/update-exim4.conf.conf


echo "[+] 创建自定义 Exim4 配置模板..."

IP=$(curl http://ifconfig.me)

echo """
primary_hostname = ${IP}
domainlist local_domains = *
acl_smtp_rcpt = acl_check_rcpt
begin acl
acl_check_rcpt:
  accept
begin routers
save_mail_router:
  driver = accept
  transport = save_mail_transport
begin transports
save_mail_transport:
  driver = pipe
  command = /usr/bin/python3 /opt/email/save_mail
  return_output
begin retry
* * F,2h,15m
begin rewrite
begin authenticators
""" > /etc/exim4/exim4.conf.template 

echo "[+] 生成配置文件并重启 Exim4..."
update-exim4.conf
systemctl restart exim4


mkdir -p "/opt/email"

wget -qO /opt/email/server https://raw.githubusercontent.com/chuben/script/main/email/server
wget -qO /opt/email/save_mail https://raw.githubusercontent.com/chuben/script/main/email/save_mail

chmod +x /opt/email/save_mail
chmod +x /opt/email/server
chown -R Debian-exim:Debian-exim /opt/email
chmod -R 750 /opt/email

cat > /etc/systemd/system/simple_mail_server.service <<EOF
[Unit]
Description=Simple Mail Server (Flask + SMTP)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/email
ExecStart=/opt/email/server
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable simple_mail_server
systemctl restart simple_mail_server
