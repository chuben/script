#!/bin/bash

set -e

[ "$1" ] && KEY="$1" || exit 1

# ========== 配置区 ==========
SNI_DOMAIN="www.amazon.com"
TLS_PWD_ENC="U2FsdGVkX19Ab1SaL2IwIkKxTVJuH4tWPzlIoWSQJpJkB94osXOVE7sALt/FuNqF"
TLS_PWD=$(echo "$TLS_PWD_ENC" | openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -pass pass:"$KEY")
SS_PORT=8388
LISTEN_PORT=443
SS_KEY_ENC="U2FsdGVkX185DMhWsTggPSOApjNwLDaciJ7IjJoQdFMS5yMhSzAEKV60bvDPB+Ba"
SS_KEY=$(echo "$SS_KEY_ENC" | openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -pass pass:"$KEY")

# ============================

log(){ echo -e "\033[32m[✓]\033[0m $1"; }
err(){ echo -e "\033[31m[✗]\033[0m $1"; exit 1; }

# ── 1. 安装依赖 ─────────────────────────
apt-get update -qq
apt-get install -y -qq curl wget tar

# ── 2. 安装 ss-rust ─────────────────────
if ! command -v ssserver &>/dev/null; then
    log "安装 Shadowsocks-Rust..."
    wget -q https://github.com/shadowsocks/shadowsocks-rust/releases/download/v1.24.0/shadowsocks-v1.24.0.x86_64-unknown-linux-gnu.tar.xz
    tar xf shadowsocks-*.tar.xz
    mv ssserver /usr/local/bin/
    chmod +x /usr/local/bin/ssserver
    rm -f shadowsocks-*.tar.xz
fi

# ── 3. 安装 shadow-tls ──────────────────
if ! command -v shadow-tls &>/dev/null; then
    log "安装 Shadow-TLS..."
    wget -q https://github.com/ihciah/shadow-tls/releases/download/v0.2.25/shadow-tls-x86_64-unknown-linux-musl
    mv shadow-tls-x86_64-unknown-linux-musl /usr/local/bin/shadow-tls
    chmod +x /usr/local/bin/shadow-tls
fi

# ── 4. 写配置文件 ───────────────────────
mkdir -p /etc/shadowtls

cat > /etc/shadowtls/ss.conf <<EOF
SS_PORT=${SS_PORT}
SS_KEY=${SS_KEY}
EOF

cat > /etc/shadowtls/tls.conf <<EOF
LISTEN_PORT=${LISTEN_PORT}
SNI_DOMAIN=${SNI_DOMAIN}
TLS_PWD=${TLS_PWD}
SS_PORT=${SS_PORT}
EOF

# ── 5. systemd: ss-rust ────────────────
cat > /etc/systemd/system/ss-rust.service <<EOF
[Unit]
Description=Shadowsocks Rust Server
After=network.target

[Service]
ExecStart=/usr/local/bin/ssserver \\
    --server-addr 127.0.0.1:${SS_PORT} \\
    --encrypt-method 2022-blake3-aes-128-gcm \\
    --password ${SS_KEY} \\
    --timeout 300 -U
Restart=always
RestartSec=3
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

# ── 6. systemd: shadow-tls ─────────────
cat > /etc/systemd/system/shadow-tls.service <<EOF
[Unit]
Description=Shadow-TLS Server
After=network.target ss-rust.service
Requires=ss-rust.service

[Service]
ExecStart=/usr/local/bin/shadow-tls \\
    --v3 server \\
    --listen 0.0.0.0:${LISTEN_PORT} \\
    --server 127.0.0.1:${SS_PORT} \\
    --tls ${SNI_DOMAIN}:443 \\
    --password ${TLS_PWD}
Restart=always
RestartSec=3
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

# ── 7. 启动服务 ─────────────────────────
systemctl daemon-reexec
systemctl daemon-reload

systemctl enable ss-rust
systemctl enable shadow-tls

systemctl restart ss-rust
sleep 1
systemctl restart shadow-tls

# ── 8. 检查状态 ─────────────────────────
sleep 2

systemctl is-active --quiet ss-rust || err "ss-rust 启动失败"
systemctl is-active --quiet shadow-tls || err "shadow-tls 启动失败"

log "服务运行正常"

# ── 9. 获取 IP ─────────────────────────
SERVER_IP=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me)

# ── 10. 生成链接 ───────────────────────
SS_B64=$(python3 -c "
import base64
print(base64.urlsafe_b64encode(b'2022-blake3-aes-128-gcm:${SS_KEY}').decode().rstrip('='))
")

STLS_B64=$(python3 -c "
import base64, json
obj={'version':'3','host':'${SNI_DOMAIN}','password':'${TLS_PWD}'}
print(base64.urlsafe_b64encode(json.dumps(obj,separators=(',',':')).encode()).decode().rstrip('='))
")

LINK="ss://${SS_B64}@${SERVER_IP}:${LISTEN_PORT}?shadow-tls=${STLS_B64}#$SERVER_IP"

echo ""
echo "════════════════════════════════"
echo "  部署完成（systemd版）"
echo "════════════════════════════════"
echo "  ${LINK}"
echo "════════════════════════════════"