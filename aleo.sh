#!/bin/bash

BIN="aleo-pool-prover"
DIR="/opt/aleo"
mkdir $DIR 2>/dev/null

WORKER_NAME="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4 | sed 's/\./-/g')"

function zklion() {
    COMMANDS="$BIN --account run2024 --pool wss://aleo.zklion.com:3777 --worker-name $WORKER_NAME"

    curl -sSf -L -o $DIR/$BIN https://github.com/zklion-miner/Aleo-miner/releases/download/v0.3/aleo-pool-prover-zklion-v0.3

    if [ "$?" -ne 0 ]; then
        echo -e "\033[31mFailed to download $BIN!\033[0m"
        exit 1
    fi
}

function zkrush() {
    COMMANDS="$BIN --account run2024 --pool wss://aleo.zkrush.com:3333 --worker-name $WORKER_NAME"
    curl -sSf -L -o $DIR/$BIN https://github.com/zkrush/aleo-pool-client/releases/download/v1.6-testnet-beta/aleo-pool-prover

    if [ "$?" -ne 0 ]; then
        echo -e "\033[31mFailed to download $BIN!\033[0m"
        exit 1
    fi
}


if [ -z "$1" ] || [ "$1" == "zklion" ]
then
zklion
elif [ "$1" == "zkrush" ]
then
zkrush
else
exit 1
fi

chmod +x $DIR/$BIN

echo """[Unit]
Description=aleo
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$DIR/$COMMANDS
Restart=always
RestartSec=5s
StandardOutput=file:$DIR/prover.log
StandardError=inherit
[Install]
WantedBy=default.target""" > /etc/systemd/system/aleo.service

systemctl daemon-reload
systemctl enable aleo
systemctl start aleo
