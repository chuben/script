#!/bin/bash
[ "$1" ] && WALLET_ADDR="$1" || WALLET_ADDR="44zjbqhegCJ2WpGUtjTiAY3Jh5PgNyNyaMNiJX9rBcSXK3Nvv6LwSWFc2Qww8mgWJEi6PwAssTgH9c8dkxyXYR78K1gS4xA"
INSTALL_DIR="/opt/tari"
SERVICE_NAME="tari"

[ ! "$(which wget)" ] && apt-get update && apt-get install -y wget

[ -d "$INSTALL_DIR" ] && rm -rf $INSTALL_DIR

mkdir -p "$INSTALL_DIR"

wget -qO-  https://github.com/xmrig/xmrig/releases/download/v6.22.2/xmrig-6.22.2-jammy-x64.tar.gz | tar -zxf - -C $INSTALL_DIR --strip-components=1

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

echo "exec $INSTALL_DIR/xmrig --url pool.hashvault.pro:443 --user $WALLET_ADDR --pass \$minerAlias --donate-level 1 --tls --tls-fingerprint 420c7850e09b7c0bdcf748a7da9eb3647daf8515718f36d9ccfdd6b9ff834b14">> $INSTALL_DIR/start.sh

chmod +x $INSTALL_DIR/start.sh

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=tari Mining Pool Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start.sh
Restart=always
RestartSec=30
Environment="LD_LIBRARY_PATH=$INSTALL_DIR"

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME
