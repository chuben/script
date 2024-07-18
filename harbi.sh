#!/bin/bash

dir="/opt/harbi"
[ ! -d $dir ] && mkdir $dir
addr="harbi:qp8ppmvdn2cdqk5yns4zajpdz0aj58hwt9spyhrfvshfdcqrn5qhuxtc3jzl7"
cd $dir

wget https://github.com/harbi-network/harbid/releases/download/0.1.4/linux.zip -O /tmp/linux.zip
[ "$?" -ne 0 ] && exit 1

unzip /tmp/linux.zip -d $dir
[ "$?" -ne 0 ] && exit 1

chmod +x $dir/*

mkdir -p ~/.har/harbi-mainnet

wget https://harbi.aws2024.shop/datadir2.tar.gz -O - | tar -zxf - -C ~/.har/harbi-mainnet/

unzip /tmp/datadir2.zip -d /root/.har/harbi-mainnet/datadir2

echo """
[Unit]
Description=harbi
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$dir
ExecStart=$dir/harbiminer --miningaddr=$addr
Restart=always
RestartSec=5s
StandardOutput=file:$dir/miner.log
StandardError=file:$dir/miner.log
[Install]
WantedBy=default.target
""" > /etc/systemd/system/harbiminer.service

echo """
[Unit]
Description=harbi utxoindex
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$dir
ExecStart=$dir/harbid --utxoindex --rpcmaxclients=99999
Restart=always
RestartSec=5s
StandardOutput=file:$dir/utxoindex.log
StandardError=file:$dir/utxoindex.log
[Install]
WantedBy=default.target
""" > /etc/systemd/system/harbid.service


systemctl enable harbid harbiminer
systemctl restart harbid harbiminer