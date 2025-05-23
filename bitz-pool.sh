#!/bin/bash
[ "$1" ] && WALLET_ADDR="$1" || WALLET_ADDR="SbxQm8HWUQefijEd8KDJkQMKbnpxvEDdBNweDXhH6T6"
SERVER_URL="http://minebitz1.oreminepool.top:8880/"
INSTALL_DIR="/opt/bitz"
SERVICE_NAME="bitz"

apt-get update
apt-get install -y wget

mkdir -p "$INSTALL_DIR"

[ -f "$INSTALL_DIR/ore-mine-pool-linux-avx512" ] && rm -rf "$INSTALL_DIR/ore-mine-pool-linux-avx512"

cd $INSTALL_DIR
wget -q --show-progress https://github.com/xintai6660707/ore-mine-pool/raw/refs/heads/main/ore-mine-pool-linux-avx512

echo '''#!/bin/bash
ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
[ -z "$ip" ] && exit 1

declare -A encrypt_dict=(
    ["0"]="a" ["1"]="b" ["2"]="c" ["3"]="d" ["4"]="e"
    ["5"]="f" ["6"]="g" ["7"]="h" ["8"]="i" ["9"]="j"
    ["."]="k"
)

encrypt_ip() {
    local ip=$1
    local result=""
    for (( i=0; i<${#ip}; i++ )); do
        char="${ip:$i:1}"
        result+="${encrypt_dict[$char]:-$char}"
    done
    echo "$result"
}

minerAlias=$(encrypt_ip "$ip")

''' > $INSTALL_DIR/start.sh

echo "$INSTALL_DIR/ore-mine-pool-linux-avx512 worker --route-server-url '$SERVER_URL'  --server-url 'bitz' --worker-wallet-address '$WALLET_ADDR' --alias \$minerAlias">> $INSTALL_DIR/start.sh

chmod +x ore-mine-pool-linux-avx512
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
