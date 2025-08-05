#!/bin/bash

apt update -y
apt install wget -y

mkdir -p "/opt/email"

wget -qO /opt/email/simple_mail_server https://raw.githubusercontent.com/chuben/script/main/email/simple_mail_server

chmod +x /opt/email/simple_mail_server

cat > /etc/systemd/system/simple_mail_server.service <<EOF
[Unit]
Description=Simple Mail Server (Flask + SMTP)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/email
ExecStart=/opt/email/simple_mail_server
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl stop exim4
sudo systemctl disable exim4

systemctl daemon-reload
systemctl enable simple_mail_server
systemctl restart simple_mail_server
