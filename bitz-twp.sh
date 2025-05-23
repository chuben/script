#!/bin/bash
[ "$1" ] && WALLET_ADDR="$1" || WALLET_ADDR="SbxQm8HWUQefijEd8KDJkQMKbnpxvEDdBNweDXhH6T6"
INSTALL_DIR="/opt/bitz"
SERVICE_NAME="bitz"

apt-get update
apt-get install -y wget

mkdir -p "$INSTALL_DIR"

[ -f "$INSTALL_DIR/OrionClient" ] && rm -rf "$INSTALL_DIR/OrionClient"

cd $INSTALL_DIR

wget -qO-  https://github.com/egg5233/OrionClient_tw/releases/download/1.6.0/OrionClient.tar.gz | tar -zxf - -C $INSTALL_DIR --strip-components=1

echo '''#!/bin/bash
ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
[ -z "$ip" ] && exit 1
instype=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/instance-type| sed "s/xlarge//g"|sed "s/\.//g")
[ -z "$instype" ] && exit 1
country=$(wget -T 3 -t 2 -qO - http://169.254.169.254/2021-03-23/meta-data/placement/availability-zone|cut -b 1-2 )
[ -z "$country" ] && exit 1
minerAlias=${country}_${instype}_$ip
minerAlias=`echo $minerAlias|sed "s/\./-/g"`
''' > $INSTALL_DIR/start.sh

echo "$INSTALL_DIR/OrionClient mine -a --pool twbitz --key '$WALLET_ADDR' --worker \$minerAlias">> $INSTALL_DIR/start.sh

chmod +x $INSTALL_DIR/start.sh

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=BITZ Mining Pool Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start.sh
Restart=always
RestartSec=30
StandardOutput=syslog
StandardError=syslog
Environment="LD_LIBRARY_PATH=$INSTALL_DIR"

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME
