#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量 (可自定义)
CLAIM_INTERVAL_HOURS=6      # 每6小时claim一次
MAX_RETRIES=3               # 失败最大重试次数
BACKUP_DIR="$HOME/.bitz_backups"  # 备份目录

# 1️⃣ 安装Rust
install_rust() {
  echo -e "${YELLOW}[1/8] 正在安装Rust...${NC}"
  if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo -e "${GREEN}Rust安装成功！版本: $(rustc --version)${NC}"
  else
    echo -e "${GREEN}检测到Rust已安装: $(rustc --version)${NC}"
  fi
}

# 2️⃣ 安装Solana CLI
install_solana() {
  echo -e "${YELLOW}[2/8] 正在安装Solana CLI...${NC}"
  if ! command -v solana &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash
    echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    echo -e "${GREEN}Solana安装成功！版本: $(solana --version)${NC}"
  else
    echo -e "${GREEN}检测到Solana已安装: $(solana --version)${NC}"
  fi
}

# 3️⃣ 增强版钱包设置（调整到关键位置）
setup_wallet() {
  echo -e "\n${YELLOW}[3/8] 正在设置钱包...${NC}"
  local wallet_file="$HOME/.config/solana/id.json"
  
  # 安全创建目录
  mkdir -p "$(dirname "$wallet_file")" "$BACKUP_DIR" || {
    echo -e "${RED}错误：无法创建目录${NC}"
    exit 1
  }

  if [ -n "$1" ]; then
    echo -e "${BLUE}检测到密钥输入，安全导入中...${NC}"

    if [[ "$1" =~ ^\[.*\]$ ]]; then
      echo "$1" > "$wallet_file"
    else
      solana-keygen recover --force -o "$wallet_file" prompt: <<< "$1" || {
        echo -e "${RED}密钥导入失败！${NC}"
        exit 1
      }
    fi
    chmod 600 "$wallet_file"
  fi

  if [ ! -f "$wallet_file" ]; then
    echo -e "${YELLOW}生成新钱包...${NC}"
    export RUSTFLAGS='-C target-feature=+aes,+ssse3'
    solana-keygen new --no-bip39-passphrase --force -o "$wallet_file"
    chmod 600 "$wallet_file"
  fi

  # 备份钱包
  local backup_file="$BACKUP_DIR/wallet_$(date +%s).json"
  cp "$wallet_file" "$backup_file"
  echo -e "\n${GREEN}✅ 钱包地址: $(solana address -k "$wallet_file")"
  echo -e "${BLUE}🔐 备份位置: $backup_file${NC}\n"
}

# 4️⃣ 安装Bitz
install_bitz() {
  echo -e "${YELLOW}[4/8] 正在安装Bitz...${NC}"
  if ! command -v bitz &> /dev/null; then
    cargo install bitz --locked
    echo -e "${GREEN}Bitz安装成功！${NC}"
  else
    echo -e "${GREEN}检测到Bitz已安装${NC}"
  fi
}

# 5️⃣ 配置RPC
configure_rpc() {
  echo -e "${YELLOW}[5/8] 正在配置RPC...${NC}"
  solana config set --url https://mainnetbeta-rpc.eclipse.xyz
  echo -e "${GREEN}当前RPC配置:${NC}"
  solana config get
}

# 6️⃣ 新增：自动claim功能
start_claim_daemon() {
  echo -e "${YELLOW}[6/8] 配置自动claim服务...${NC}"

  # 创建自动应答脚本
  cat > /usr/local/bin/auto_claim <<EOF
#!/bin/bash
source ~/.bashrc
source "$HOME/.cargo/env"
for i in {1..$MAX_RETRIES}; do
  echo "尝试第\$i次claim (自动确认y)..."
  if expect -c '
    set timeout 300
    spawn bitz claim
    expect {
      "y/n" { send "y\\r"; exp_continue }
      eof
    }
  '; then
    echo "\$(date) claim成功"
    exit 0
  else
    echo "\$(date) claim失败，等待重试..."
    sleep \$((i*60))
  fi
done
exit 1
EOF

  chmod +x /usr/local/bin/auto_claim

  # 创建systemd服务
  cat > /etc/systemd/system/bitz-claim.service <<EOF
[Unit]
Description=Bitz Auto Claim Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$HOME
ExecStart=/bin/bash -c 'while true; do \
  /usr/local/bin/auto_claim && \
  sleep $((CLAIM_INTERVAL_HOURS*3600)); \
done'
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable bitz-claim
  systemctl start bitz-claim
  
  echo -e "${GREEN}自动claim服务已部署! 特性:"
  echo -e "• 自动应答 y/n 确认"
  echo -e "• 失败后指数退避重试 (最多$MAX_RETRIES次)"
  echo -e "• 每${CLAIM_INTERVAL_HOURS}小时运行一次${NC}"
}

# 7️⃣ 增强版挖矿启动
start_mining() {
  echo -e "${YELLOW}[7/8] 启动挖矿系统...${NC}"
  
  screen -XS eclipse quit || true
  
  screen -dmS eclipse bash -c "
    exec > >(tee -a $HOME/mining.log) 2>&1
    while true; do
      echo \"\$(date) 启动挖矿进程\"
      bitz collect || {
        echo \"\$(date) 挖矿崩溃，10秒后重启...\"
        sleep 10
      }
    done
  "
  
  echo -e "${GREEN}挖矿已启动! 使用 ${BLUE}screen -r eclipse ${GREEN}查看${NC}"
  echo -e "${YELLOW}实时日志: ${BLUE}tail -f $HOME/mining.log${NC}"
}

# 8️⃣ 新增：收益监控
setup_monitoring() {
  echo -e "${YELLOW}[8/8] 配置收益追踪...${NC}"
  
  apt-get install -y jq bc
  
  cat > /usr/local/bin/mining_stats <<EOF
#!/bin/bash
source ~/.bashrc
source "$HOME/.cargo/env"
balance_now=\$(solana balance -k ~/.config/solana/id.json | awk '{print \$1}')
echo -e "当前余额: \${balance_now} SOL"
EOF
  
  chmod +x /usr/local/bin/mining_stats
  echo -e "${GREEN}监控工具已安装! 使用 ${BLUE}mining_stats ${GREEN}查看收益${NC}"
}

# 主流程
main() {
  echo -e "\n${GREEN}===== Eclipse矿工 v2.1 =====${NC}"
  
  # 初始化环境
  apt-get update
  apt-get install -y screen jq curl git build-essential expect

  install_rust
  install_solana
  setup_wallet "$1"
  install_bitz
  configure_rpc
  start_claim_daemon
  start_mining
  setup_monitoring
  
  echo -e "\n${GREEN}✔ 所有系统启动完成!${NC}"
  echo -e "${BLUE}📊 监控命令:"
  echo -e " 收益统计: mining_stats"
  echo -e " 挖矿日志: tail -f $HOME/mining.log"
  echo -e " Claim日志: journalctl -u bitz-claim -f${NC}"
  
  # 最后再次突出显示钱包信息
  echo -e "\n${YELLOW}⚠️ 重要！请妥善保管以下信息:"
  echo -e "${GREEN}钱包地址: $(solana address -k ~/.config/solana/id.json)"
  echo -e "备份文件: $(ls -t $BACKUP_DIR/wallet_*.json | head -1)${NC}"
  echo -e "${YELLOW}请将此地址复制到Backpack钱包进行核对:${NC}"
  cat ~/.config/solana/id.json | jq -c . 2>/dev/null || echo -e "${RED}请手动复制文件内容: ~/.config/solana/id.json${NC}"
}

main "$@"