#!/bin/bash
[ -z "$1" ] && exit 1
password="$1"
reboot_sw=0

apt update -y
apt upgrade -y

function update_image(){
    rm -rf  /boot/*cloud*
    apt install -y linux-image-5.10.0-33-amd64
    update-grub
    reboot_sw=1
}

uname -r | grep cloud && update_image


DEBIAN_FRONTEND=noninteractive apt install python3-pip ppp iptables-persistent netfilter-persistent  net-tools curl -y


echo '''
name sstpd
require-mschap-v2
nologfd
nodefaultroute
ms-dns 192.168.88.1''' > /etc/ppp/options.sstpd


echo '''
# Secrets for authentication using CHAP
# client        server  secret                  IP addresses
run2024 * 184224412 *
''' > /etc/ppp/chap-secrets

dev=` ip route | grep default|awk '{print $5}'`
iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -o $dev -j MASQUERADE
netfilter-persistent save
sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g"  /etc/sysctl.conf && sysctl -p

mkdir -p /etc/ssl/certs/sstp
wget https://raw.githubusercontent.com/chuben/script/main/fullchain.pem.gpg
wget https://raw.githubusercontent.com/chuben/script/main/privkey.pem.gpg
gpg -d --batch --passphrase="$password" fullchain.pem.gpg > /etc/ssl/certs/sstp/fullchain.pem
gpg -d --batch --passphrase="$password" privkey.pem.gpg > /etc/ssl/certs/sstp/privkey.pem


pip3 install sstp-server

echo """[Unit]
Description=tdc
DefaultDependencies=no
After=network.target

[Service]
Type=simple
User=root
ExecStart=sstpd -c /etc/ssl/certs/sstp/fullchain.pem -k /etc/ssl/certs/sstp/privkey.pem --local 192.168.88.1 --remote 192.168.88.0/24 -p 9443 -l 0.0.0.0
Restart=always
RestartSec=5s
[Install]
WantedBy=default.target""" >/etc/systemd/system/sstp.service

systemctl daemon-reload
systemctl enable sstp
systemctl restart sstp

bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/dns.sh)

[ "$reboot_sw" -eq 1 ] && reboot