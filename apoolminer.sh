#!/bin/bash

set -e

echo "========== apoolminer 自动安装并注册为服务 =========="

[ "$1" ] && ACCOUNT="$1" || ACCOUNT="CP_2b4k7rqhk2"
INSTALL_DIR="/opt/apoolminer"
SERVICE_FILE="/etc/systemd/system/apoolminer.service"
POOL="qubic1.hk.apool.io:3334"
mkdir -p "$INSTALL_DIR"

# 安装依赖
echo "安装必要组件..."
apt update && apt install -y wget tar

# 下载
echo "下载 apoolminer..."
VERSION=$(wget -qO- https://api.github.com/repos/apool-io/apoolminer/releases/latest | grep tag_name | cut -d '"' -f 4)
[ "$?" -ne 0 ] || [ -z "$VERSION" ] && VERSION='v3.1.0'
DOWNLOAD_URL="https://github.com/apool-io/apoolminer/releases/download/${VERSION}/apoolminer_linux_${VERSION}.tar"
wget -qO- "$DOWNLOAD_URL" | tar -zxf - -C $INSTALL_DIR


# 创建 systemd 服务
echo "创建 systemd 服务文件..."

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

''' > $INSTALL_DIR/run.sh

echo "exec ${INSTALL_DIR}/apoolminer --algo qubic_xmr --account ${ACCOUNT} --worker \$minerAlias --pool ${POOL}" >> $INSTALL_DIR/run.sh

chmod +x $INSTALL_DIR/run.sh

tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Apool XMR Miner
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/run.sh
Restart=always
RestartSec=30
Environment="LD_LIBRARY_PATH=$INSTALL_DIR"

[Install]
WantedBy=multi-user.target
EOF


# 启动服务
echo "启用并启动 apoolminer 服务..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable apoolminer
systemctl start apoolminer