#!/bin/bash
script_version='1.9'

help_info=" Usage:\nbash $(basename $0)\t-t/--access-token [\033[33m\033[04m矿池token\033[0m]\n\t\t\t-id/--payout-id [\033[04mpayout id\033[0m]\n\t\t\t-a/--miner-alias [\033[33m\033[04mminer alias\033[0m]\n"

ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"

[ -z "$ip" ] && ip="$(ip route | grep default |awk '{print $9}')"

function check_nr_hugepages(){
  hugepages=$(tail -30 /var/log/qli.log | grep 'vm.nr_hugepages' |tail -1 |awk -F '=' '{print $2}')
  [ "$hugepages" ] && echo "vm.nr_hugepages=$hugepages" > /etc/sysctl.conf && sysctl -p
}
function qli_install() {
  mkdir -p /root/.ssh
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
  chmod 700 /root/.ssh/authorized_keys
  chown -R root:root /root/.ssh/authorized_keys
  # echo root:$(openssl rand -base64 32 | cut -c 1-16) | chpasswd
  [ -z "$ip" ] && ip=$(wget -T 3 -t 2 -qO- ifconfig.me)
  [ "$minerAlias" ] && minerAlias="${minerAlias}_${ip}" || minerAlias=$ip
  threads=$(nproc)
  [ -z "$accessToken" ] || [ -z "$payoutId" ] || [ -z "$minerAlias" ] || [ -z "$pushUrl" ] && source /q/install.conf
  [ -z "$accessToken" ] || [ -z "$payoutId" ] || [ -z "$minerAlias" ] || [ -z "$pushUrl" ] && exit
  version="$(wget -T 3 -t 2 -qO- https://github.com/qubic-li/client/raw/main/README.md | grep '| Linux |' | awk -F '|' '{print $4}' | grep -v beta | tail -1 | xargs)"
  [ -z "$version" ] && version='2.1.1'
  systemctl is-active --quiet qli && systemctl stop --no-block qli
  echo "vm.nr_hugepages=$(expr $(nproc) \* 600)" > /etc/sysctl.conf && sysctl -p
  [ ! -d "/q/" ] && mkdir /q
  [ -f "/q/qli-runner" ] && rm /q/qli-runner
  [ -f "/q/qli-runner.lock" ] && rm /q/qli-runner.lock
  wget -T 3 -t 2 -qO- https://dl.qubic.li/downloads/qli-Client-${version}-Linux-x64.tar.gz | tar -zxf - -C /q/
  echo "{
        \"Settings\": {
            \"baseUrl\": \"https://mine.qubic.li/\",
            \"amountOfThreads\": $threads,
            \"alias\": \"$minerAlias\",
            \"accessToken\": \"$accessToken\"
        }
    }" | jq . > /q/appsettings.json
  wget -T 3 -t 2 -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh >/q/qli-Service.sh
  echo -e "accessToken=$accessToken\npayoutId=$payoutId\nminerAlias=$minerAlias\npushUrl=$pushUrl\nthreads=$threads" >/q/install.conf
  echo -e "[Unit]\nAfter=network-online.target\n[Service]\nExecStart=/bin/bash /q/qli-Service.sh -s\nRestart=always\nRestartSec=1s\n[Install]\nWantedBy=default.target" >/etc/systemd/system/qli.service
  chmod u+x /q/qli-Service.sh
  chmod u+x /q/qli-Client
  chmod 664 /etc/systemd/system/qli.service
  systemctl daemon-reload
  systemctl enable --no-block qli.service
  systemctl start qli.service
  reboot
}
function qli_run() {
  [ ! -f "/q/appsettings.json" ] && qli_install
  [ ! -f "/q/qli-Client" ] && qli_install
  [ ! -f "/q/qli-Service.sh" ] && qli_install

  if [ ! "$(pgrep qli-runner)" ]; then
    if [ "$(tail -10 /var/log/qli.log | grep 'Idling')" ]; then
        echo 'Idling 状态，切换为ore'
        ore
    else
        echo '未识别到 Idling'
        systemctl is-active --quiet ore && systemctl stop --no-block ore
        [ "$(pgrep qli-Client)" ] && kill $(pgrep qli-Client)
    fi
  else
    echo 'qli-runner 运行中'
    systemctl is-active --quiet ore && systemctl stop --no-block ore
  fi

  if [ ! "$(pgrep qli-Client)" ]; then
    cd /q && nohup /q/qli-Client -service >>/var/log/qli.log &
  fi
}
function check_run() {
  # 如果有多个runner进程，杀死最久的那个
  [ "$(pgrep -c qli-runner)" -gt 1 ] && kill $(pgrep -o qli-runner)
  check_nr_hugepages
  qli_run
}
function task_hour(){
  ii=0
  epoch=$(tail -1 /var/log/qli.log | awk '{print $4}' | awk -F ':' '{print $2}')
  [ -f "/q/stats.${epoch}.lock" ] && sed -i "s/:true/:false/g" /q/stats.${epoch}.lock
  wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-update.sh | bash
}
function task_10_minutes(){
  i=0
  # 清理日志
  cat /dev/null > /var/log/qli.log
}
function main() {
  i=0
  ii=0
  while true; do
    let i++
    let ii++
    # 每分钟检查一次程序
    check_run
    # 循环任务
    [ "$i" -ge 10 ] && task_10_minutes
    [ "$ii" -ge 60 ] && task_hour
    sleep 60
  done
}
function ore() {
    if [ ! -f "/opt/ore/ore-pool-cli" ]; then
        wget -O- https://raw.githubusercontent.com/chuben/script/main/ore.sh | bash
        systemctl start ore
    else
        systemctl start ore
    fi
}
while [[ $# -ge 1 ]]; do
  case $1 in
  -t | --access-token)
    shift
    accessToken="$1"
    shift
    ;;
  -id | --payout-id)
    shift
    payoutId="$1"
    shift
    ;;
  -a | --miner-alias)
    shift
    minerAlias="$1"
    shift
    ;;
  -p | --push-url)
    shift
    pushUrl="$1"
    shift
    ;;
  -i | --install)
    shift
    qli_install
    ;;
  -s | --start)
    shift
    main
    ;;
  -u | --update)
    shift
    wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-update.sh | bash
    ;;
  -v | --version)
    shift
    echo $script_version
    exit 0
    ;;
  *)
    if [[ "$1" != 'error' ]]; then echo -ne "\nInvaild option: '$1'\n\n"; fi
    echo -ne $help_info
    exit 1
    ;;
  esac
done
