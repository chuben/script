#!/bin/bash

[ -z "$1" ] && exit || psw=$1

export DEBIAN_FRONTEND=noninteractive
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

vmlinuz_version=`ls /boot/vmlinuz* |tail -1 |awk -F '-' '{print $2"-"$3}'`
apt update -y
apt install -y linux-headers-${vmlinuz_version}-amd64 linux-image-${vmlinuz_version}-amd64 \
    iptables-persistent netfilter-persistent  net-tools curl \
    certbot python3-certbot-nginx git build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
    python3-openssl ppp

[ "$?" -eq 0 ] && rm -rf /boot/*cloud*

update-grub

echo '''name sstpd
require-mschap-v2
nologfd
nodefaultroute
ms-dns 192.168.85.1''' > /etc/ppp/options.sstpd 

echo """# Secrets for authentication using CHAP
# client        server  secret                  IP addresses
ben * $psw *
vm * $psw 192.168.85.200""" > /etc/ppp/chap-secrets

curl https://pyenv.run | bash


echo '''export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"''' >> ~/.bashrc 

source ~/.bashrc 
pyenv install 3.9.7

pyenv global 3.9.7

certbot --nginx --key-type rsa -d us.flunode.icu --non-interactive --agree-tos --email admin@flunode.icu
mkdir -p /opt/sstp/

cp -f /etc/letsencrypt/live/us.flunode.icu/* /opt/sstp/.

pip3  install sstp-server

echo '''
net.ipv4.ip_forward=1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
''' >  /etc/sysctl.conf 
sysctl -p

net_name=`ip route | grep default|awk '{print $5}'`
iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -o $net_name -j MASQUERADE

netfilter-persistent save

echo '''#!/bin/bash
/root/.pyenv/shims/sstpd -c  fullchain.pem -k privkey.pem  --local 192.168.85.1 --remote 192.168.85.0/24 -p 9443 -l 0.0.0.0''' > /opt/sstp/start.sh 
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

systemctl daemon-reload
systemctl enable sstp

reboot