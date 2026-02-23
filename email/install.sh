#!/bin/bash

echo "[+] 安装必要组件..."
apt update
apt install -y curl wget

mkdir -p "/opt/email/mailstore"
mkdir -p "/opt/email/logs"

wget -qO /opt/email/server https://raw.githubusercontent.com/chuben/script/main/email/server

chmod +x /opt/email/server

cat > /etc/systemd/system/simple_mail_http.service <<EOF
[Unit]
Description=Simple Mail HTTP
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
systemctl enable simple_mail_http 
systemctl restart simple_mail_http
