#!/bin/bash
set -e

########################################
# Config
########################################

VERSION="v0.1.20"
HASH="A07A91B5-E603-446A-85A7-8440D1333F4E"

DOWNLOAD_URL="https://github.com/Titannet-dao/titan-node/releases/download/${VERSION}/titan-edge_${VERSION}_246b9dd_linux-amd64.tar.gz"

WORKDIR="/opt/titan"
STORAGE_PATH="/opt/storage"

########################################
# Install packages
########################################

apt-get update
apt-get install -y wget tar

########################################
# Download
########################################

mkdir -p "$WORKDIR"
cd /tmp

wget -O titan.tar.gz "$DOWNLOAD_URL"

rm -rf titan-edge_*
tar -zxf titan.tar.gz

EXTRACT_DIR=$(find . -maxdepth 1 -type d -name "titan-edge_*" | head -1)

########################################
# Install binary
########################################

cp "${EXTRACT_DIR}/libgoworkerd.so" /usr/local/lib/
cp "${EXTRACT_DIR}/titan-edge" /usr/local/bin/

chmod +x /usr/local/bin/titan-edge

ldconfig

########################################
# Storage
########################################

mkdir -p "$STORAGE_PATH"

########################################
# Init node
########################################

if [ ! -d /root/.titanedge ]; then
  titan-edge daemon start \
      --init \
      --url https://cassini-locator.titannet.io:5000/rpc/v0 \
      >/tmp/titan-init.log 2>&1 &

  PID=$!

  sleep 20

  titan-edge bind --hash="$HASH" \
      https://api-test1.container1.titannet.io/api/v2/device/binding

  titan-edge config set --storage-path /opt/storage
  titan-edge config set --storage-size 50GB

  kill $PID || true

  sleep 5
fi

########################################
# Systemd
########################################

cat >/etc/systemd/system/titan-edge.service <<'EOF'
[Unit]
Description=Titan Edge Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=10

Environment=LD_LIBRARY_PATH=/usr/local/lib

ExecStart=/usr/local/bin/titan-edge daemon start \
  --url https://cassini-locator.titannet.io:5000/rpc/v0

ExecStop=/usr/local/bin/titan-edge daemon stop

LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

########################################
# Enable
########################################

systemctl daemon-reload
systemctl enable titan-edge
systemctl restart titan-edge

echo
echo "================================="
echo "Titan installed successfully"
echo "================================="
systemctl status titan-edge --no-pager