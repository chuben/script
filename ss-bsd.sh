#!/bin/sh
# 一键安装 shadowsocks-rust 并生成客户端订阅地址
# FreeBSD 14.3 适用

[ "$1" ] && PASSWORD="$1" || exit 1

# -----------------------------
# 1. 安装 shadowsocks-rust
# -----------------------------
echo "=== 更新 pkg 仓库并安装 shadowsocks-rust ==="
pkg update
pkg install -y shadowsocks-rust jq

echo """
########## macOS-like TCP profile ##########

# 禁用 TCP 分段卸载（避免虚拟化特征）
net.inet.tcp.tso=0

# 启用 SACK（macOS 默认开启）
net.inet.tcp.sack.enable=1

# 启用 TCP timestamps（macOS 默认开启）
net.inet.tcp.send_timestamps=1
net.inet.tcp.recv_timestamps=1

# 默认 MSS（以太网常见）      
net.inet.tcp.mssdflt=1460

# TCP 窗口大小（macOS 风格）
net.inet.tcp.sendspace=65535
net.inet.tcp.recvspace=65535

# 禁用 TCP blackhole（避免异常行为）
net.inet.tcp.blackhole=0
net.inet.udp.blackhole=0

# 允许 Path MTU Discovery
net.inet.tcp.path_mtu_discovery=1

###########################################
""" > /etc/sysctl.conf

service sysctl restart
                
# -----------------------------
# 2. 生成配置文件
# -----------------------------
CONFIG_FILE="/usr/local/etc/shadowsocks-rust/config.json"
PORT=8388
METHOD="aes-256-gcm"

echo "=== 生成配置文件: $CONFIG_FILE ==="
mkdir -p /usr/local/etc/shadowsocks-rust
cat > $CONFIG_FILE <<EOF
{
  "server": "0.0.0.0",
  "server_port": $PORT,
  "password": "$PASSWORD",
  "method": "$METHOD",
  "timeout": 300
}
EOF

# -----------------------------
# 3. 创建 rc 脚本
# -----------------------------
RC_SCRIPT="/usr/local/etc/rc.d/shadowsocks_rust"
echo "=== 创建 rc 脚本: $RC_SCRIPT ==="
cat > $RC_SCRIPT <<'EORC'
#!/bin/sh
#
# PROVIDE: shadowsocks_rust
# REQUIRE: NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="shadowsocks_rust"
rcvar=shadowsocks_rust_enable

command="/usr/sbin/daemon"
command_args="-f -p /var/run/shadowsocks_rust.pid /usr/local/bin/ssserver -c /usr/local/etc/shadowsocks-rust/config.json"

load_rc_config $name
run_rc_command "$1"

EORC

chmod +x $RC_SCRIPT

mkdir -p /var/run

# -----------------------------
# 4. 启用并启动服务
# -----------------------------
sysrc shadowsocks_rust_enable="YES"
service shadowsocks_rust start

# -----------------------------
# 5. 打印客户端订阅地址 (ss://)
# -----------------------------
# shadowsocks URL 格式: ss://base64(method:password@host:port)
IP=$(fetch -q -o - https://api.ipify.org)
SS_URI=$(echo -n "${METHOD}:${PASSWORD}@${IP}:${PORT}" | base64 -w0)
echo
echo "=== Shadowsocks 服务已启动 ==="
echo "IP: $IP"
echo "端口: $PORT"
echo "加密方式: $METHOD"
echo "密码: $PASSWORD"
echo "客户端订阅链接:"
echo "ss://$SS_URI"
echo
echo "在客户端导入 ss:// 链接即可连接。"
