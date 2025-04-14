#!/bin/bash

SERVER_URL="http://mine.oreminepool.top:8080/"
WALLET_ADDR="6Vtcd2cAq5sjr4FThMGmVvTUPtTbo8L9xJjrTxYa9dxC"
INSTALL_DIR="/opt/bitz"
SERVICE_NAME="bitz"

apt-get update
apt-get install -y wget

mkdir -p "$INSTALL_DIR"

[ -f "$INSTALL_DIR/ore-mine-pool-linux-avx512" ] && rm -rf "$INSTALL_DIR/ore-mine-pool-linux-avx512"

cd $INSTALL_DIR
wget -q --show-progress https://github.com/xintai6660707/ore-mine-pool/raw/refs/heads/main/ore-mine-pool-linux-avx512
chmod +x ore-mine-pool-linux-avx512

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=ORE Mining Pool Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/ore-mine-pool-linux-avx512 worker --server-url $SERVER_URL --worker-wallet-address $WALLET_ADDR
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
