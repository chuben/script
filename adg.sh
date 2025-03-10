#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

apt update -y
version=`uname -r|awk -F '-cloud-' '{print $1}'`
apt install linux-headers-$version-amd64 linux-image-$version-amd64 certbot python3-pip ppp iptables-persistent netfilter-persistent  net-tools curl -y

[ "$?" -eq 0 ] && rm -rf /boot/*cloud*

update-grub

echo '''name sstpd
require-mschap-v2
nologfd
nodefaultroute
ms-dns 8.8.8.8
ms-dns 8.8.4.4''' > /etc/ppp/options.sstpd 

echo """# Secrets for authentication using CHAP
# client        server  secret                  IP addresses
ben * $1 *
vm * $1 192.168.88.200""" > /etc/ppp/chap-secrets

pip3  install sstp-server

sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf
sysctl -p

iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -o ens5 -j MASQUERADE

netfilter-persistent save

echo '''#!/bin/bash
sstpd -c  fullchain.pem -k privkey.pem  --local 192.168.88.1 --remote 192.168.88.0/24 -p 9443 -l 0.0.0.0''' > /opt/sstp/start.sh 

cd /opt/sstp/
chmod +x start.sh 

echo '''[Unit]
Description=sstp

[Service]
#Type=forking
WorkingDirectory=/opt/sstp
PrivateTmp=true
ExecStart=/opt/sstp/start.sh

[Install]
WantedBy=multi-user.target''' > /etc/systemd/system/sstp.service

wget  -T 3 -t 2 -qO-  https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.57/AdGuardHome_linux_386.tar.gz | tar -zxf - -C /opt/ 
chmod +x /opt/AdGuardHome/AdGuardHome

mv /opt/AdGuardHome.yaml /opt/AdGuardHome/.

echo '''[Unit]
Description=AdGuardHome

[Service]
#Type=forking
WorkingDirectory=/opt/AdGuardHome
PrivateTmp=true
ExecStart=/opt/AdGuardHome/AdGuardHome

[Install]
WantedBy=multi-user.target''' > /etc/systemd/system/AdGuardHome.service

systemctl daemon-reload
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl enable sstp AdGuardHome

reboot