#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys
accessToken='eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJJZCI6IjFlMjIzYmU0LTFjNmMtNGJlZS1iZjdlLTc3MDg1NjJhYWNlNCIsIk1pbmluZyI6IiIsIm5iZiI6MTczNDM5OTA0OSwiZXhwIjoxNzY1OTM1MDQ5LCJpYXQiOjE3MzQzOTkwNDksImlzcyI6Imh0dHBzOi8vcXViaWMubGkvIiwiYXVkIjoiaHR0cHM6Ly9xdWJpYy5saS8ifQ.Pi7h3pCf7oAzWCVNACoMv9in6WhThrlCf7QQX-lviLKAHQHGn5EiSxTPrjbtt43z18pv9S8RbRqJtSpXnO-Ti-Os7m2Si5fPbdoyiHeszzUcWHha7SnSTcetdPjvNw8ClgFUCrQuzuyie0KUMLqoJtlzVeO1qGXY6dMD266ar2LGB4DmzTSJJ-25wI17wNnKT1Wq8JfWcISeOc3pRp6dcFHtwZDZyZdW78sfgY8aQT71WQeayzBiMgNXOg3A2yIpAn1ejzdTE70ci-xJ-r3tB3MNArNeEQONM8eepg7l706zGvXxaufrKtpN3YUTSNU5ikZ2OE3eJ4qN4juYpULxMA'
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
[ -d "/opt/scash/" ] && rm -rf /opt/scash/
mkdir /q

wget -T 3 -t 2 -qO- https://dl.qubic.li/downloads/qli-Client-${version}-Linux-x64.tar.gz | tar -zxf - -C /q/

data='{"ClientSettings":{"poolAddress":"wss://wps.qubic.li/ws","trainer":{"cpu":true,"gpu":false,"gpuVersion":"CUDA","cpuVersion":"","cpuThreads":0},"pps":true,"qubicAddress":null}}'
command='{ "command": "/opt/scash/start.sh", "arguments": ""}'
data=`echo $data | jq ".ClientSettings.alias = \"$minerAlias\""`
data=`echo $data | jq ".ClientSettings.accessToken = \"$accessToken\""`
data=`echo $data | jq ".ClientSettings.threads = $threads"`
data=`echo $data | jq ".ClientSettings.idling = $command"`
echo $data | jq . > /q/appsettings.json

wget -O- https://raw.githubusercontent.com/chuben/script/main/scash.sh | bash
systemctl disable scash
systemctl stop scash

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