#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys
accessToken='eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJJZCI6IjFlMjIzYmU0LTFjNmMtNGJlZS1iZjdlLTc3MDg1NjJhYWNlNCIsIk1pbmluZyI6IiIsIm5iZiI6MTczMjI1OTIzOSwiZXhwIjoxNzYzNzk1MjM5LCJpYXQiOjE3MzIyNTkyMzksImlzcyI6Imh0dHBzOi8vcXViaWMubGkvIiwiYXVkIjoiaHR0cHM6Ly9xdWJpYy5saS8ifQ.HhpL9NYCdajrW7_cE63EjWu5HLnBz8jqS1YZZoPxvdyFVsPEpt7M0s37AH-8lTFQE8us4V9Q_n4opGCaddBquPKeVoYL3aq1TXWzPJEQtLEs0F4oHgZlnIQgbDqEiaMt1ojn5AhIAeV16Uqd4l8hAtw7rTwWW3NY8ruZW_leYXrcTrZCI_Gus7tF7xLM7aj7uGE-c8so4fum0LgKAmaHv4teyIxhnPV5BNSCxce1I0hVdQgZZz2Cprm2Vy2coxifBXwqgVF0kzJb0GPDXjF-OHE-C8VmTdej7Tjlhtm6zJ2_ILBNQE_2d4C5aIL75A9ENrZ4uixkEhaIpw6fVtMnQA'
apt -qq update -y && apt -qq install wget jq -y

ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
instype=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/instance-type| sed "s/xlarge//g"|sed "s/\.//g")
country=$(wget -qO - http://169.254.169.254/2021-03-23/meta-data/placement/availability-zone|awk -F '-' '{print $1}' )
minerAlias=${country}_${instype}_$ip

threads=$(nproc)
version="$(wget -T 3 -t 2 -qO- https://github.com/qubic-li/client/raw/main/README.md | grep '| Linux |' | awk -F '|' '{print $4}' | grep -v beta | tail -1 | xargs)"
[ -z "$version" ] && version='3.1.0'
systemctl is-active --quiet qli && systemctl stop --no-block qli
echo "vm.nr_hugepages=$(expr $(nproc) \* 600)" > /etc/sysctl.conf && sysctl -p

[ -d "/q/" ] && rm -rf /q
[ -d "/opt/zeph/" ] && rm -rf /opt/zeph/
mkdir /q

wget -T 3 -t 2 -qO- https://dl.qubic.li/downloads/qli-Client-${version}-Linux-x64.tar.gz | tar -zxf - -C /q/

data='{ "ClientSettings": {}}'
command='{ "command": "/opt/zeph/start.sh"}'
data=`echo $data | jq ".ClientSettings.alias = \"$minerAlias\""`
data=`echo $data | jq ".ClientSettings.accessToken = \"$accessToken\""`
data=`echo $data | jq ".ClientSettings.threads = $threads"`
data=`echo $data | jq ".ClientSettings.idling = $command"`
echo $data | jq . > /q/appsettings.json

wget -O- https://raw.githubusercontent.com/chuben/script/main/zeph.sh | bash
systemctl disable zeph
systemctl stop zeph

echo -e "[Unit]\nAfter=network-online.target\n[Service]\nExecStart=/bin/bash /q/qli-Service.sh -s\nRestart=always\nRestartSec=1s\n[Install]\nWantedBy=default.target" >/etc/systemd/system/qli.service

echo '''#!/bin/bash
ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
[ -z "$ip" ] && exit 1
instype=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/instance-type| sed "s/xlarge//g"|sed "s/\.//g")
[ -z "$instype" ] && exit 1
country=$(wget -T 3 -t 2 -qO - http://169.254.169.254/2021-03-23/meta-data/placement/availability-zone|cut -b 1-2 )
[ -z "$country" ] && exit 1
minerAlias=${country}_${instype}_$ip

config_data=`jq ".ClientSettings.alias = \"$minerAlias\"" /q/appsettings.json`
echo $config_data | jq . > /q/appsettings.json
cd /q
/q/qli-Client -service''' > /q/qli-Service.sh

chmod u+x /q/qli-Service.sh
chmod u+x /q/qli-Client
chmod 664 /etc/systemd/system/qli.service
systemctl daemon-reload
systemctl enable qli.service
systemctl restart qli.service