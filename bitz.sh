#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否root用户
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}错误：请使用root用户运行此脚本${NC}"
  exit 1
fi

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

# 3️⃣ 创建/验证钱包
setup_wallet() {
  echo -e "${YELLOW}[3/8] 正在设置钱包...${NC}"
  local wallet_file="$HOME/.config/solana/id.json"
  
  if [ ! -f "$wallet_file" ]; then
    echo -e "${YELLOW}生成新钱包...${NC}"
    solana-keygen new --no-bip39-passphrase -o "$wallet_file"
  fi

  if [ -f "$wallet_file" ]; then
    echo -e "${GREEN}钱包地址: $(solana address -k "$wallet_file")${NC}"
    echo -e "${YELLOW}请将此地址复制到Backpack钱包进行核对:${NC}"
    cat "$wallet_file" | jq -c . 2>/dev/null || echo -e "${RED}请手动复制文件内容: $wallet_file${NC}"
  else
    echo -e "${RED}钱包文件创建失败！${NC}"
    exit 1
  fi
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

# 6️⃣ 启动挖矿
start_mining() {
  echo -e "${YELLOW}[6/8] 启动挖矿会话...${NC}"
  if ! screen -list | grep -q "eclipse"; then
    screen -dmS eclipse bash -c "while true; do bitz collect; sleep 10; done"
    echo -e "${GREEN}挖矿已在screen会话中启动！${NC}"
    echo -e "${YELLOW}使用命令查看运行日志: screen -r eclipse${NC}"
  else
    echo -e "${GREEN}检测到挖矿会话已在运行${NC}"
  fi
}

# 主流程
main() {
  echo -e "\n${GREEN}==== Eclipse挖矿自动化脚本 ====${NC}"
  
  # 安装依赖
  apt-get update
  apt-get install -y screen jq curl git build-essential

  install_rust
  install_solana
  setup_wallet
  install_bitz
  configure_rpc
  start_mining

  echo -e "\n${GREEN}✔ 所有操作已完成！${NC}"
  echo -e "${YELLOW}验证命令:"
  echo -e "1. 查看钱包余额: solana balance"
  echo -e "2. 查看挖矿会话: screen -r eclipse${NC}"
}

# 执行主函数
main