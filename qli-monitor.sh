#!/bin/bash
script_version='2.5'

help_info=" Usage:\nbash $(basename $0)\t-t/--access-token [\033[33m\033[04m矿池token\033[0m]\n\t\t\t-id/--payout-id [\033[04mpayout id\033[0m]\n\t\t\t-a/--miner-alias [\033[33m\033[04mminer alias\033[0m]\n"

ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
instype=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/instance-type| sed "s/xlarge//g"|sed "s/\.//g")
country=$(wget -qO - http://169.254.169.254/2021-03-23/meta-data/placement/availability-zone|awk -F '-' '{print $1}' )
minerAlias=${country}_${instype}_$ip

function check_nr_hugepages(){
  hugepages=$(tail -30 /var/log/qli.log | grep 'vm.nr_hugepages' |tail -1 |awk -F '=' '{print $2}')
  [ "$hugepages" ] && echo "vm.nr_hugepages=$hugepages" > /etc/sysctl.conf && sysctl -p
}
function qli_install() {
  mkdir -p /root/.ssh
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' >/root/.ssh/authorized_keys
  chmod 700 /root/.ssh/authorized_keys
  chown -R root:root /root/.ssh/authorized_keys
  rm -rf /etc/crontab
  apt -qq update -y && apt -qq install wget jq curl cron -y
  # echo root:$(openssl rand -base64 32 | cut -c 1-16) | chpasswd
  [ -z "$accessToken" ] && source /q/install.conf
  [ -z "$accessToken" ] && exit
  threads=$(nproc)
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
        \"accessToken\": \"$accessToken\",
        \"amountOfThreads\": $threads,
        \"alias\": \"$minerAlias\"
    }}" | jq . > /q/appsettings.json

  wget -T 3 -t 2 -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh >/q/qli-Service.sh
  echo -e "accessToken=$accessToken\nthreads=$threads" >/q/install.conf
  echo -e "[Unit]\nAfter=network-online.target\n[Service]\nExecStart=/bin/bash /q/qli-Service.sh -s\nRestart=always\nRestartSec=1s\n[Install]\nWantedBy=default.target" >/etc/systemd/system/qli.service
  echo """SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

$((RANDOM % 60)) * * * * root wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-update.sh | bash
""" > /etc/crontab
  chmod u+x /q/qli-Service.sh
  chmod u+x /q/qli-Client
  chmod 664 /etc/systemd/system/qli.service
  systemctl daemon-reload
  systemctl enable --no-block qli.service cron
  systemctl restart qli.service cron
  exit 2000
}
function qli_run() {
  [ ! -f "/q/appsettings.json" ] && qli_install
  [ ! -f "/q/qli-Client" ] && qli_install
  [ ! -f "/q/qli-Service.sh" ] && qli_install

#   [ ! "$(pgrep qli-runner)" ] && [ "$(pgrep qli-Client)" ] && kill $(pgrep qli-Client)

  if [ ! "$(pgrep qli-runner)" ]; then
    if [ "$(tail -10 /var/log/qli.log | grep 'Idling')" ]; then
        if [ "$(pgrep SRBMiner-MULTI)" ]; then
            echo 'scash 运行中'
        else
            echo 'Idling 状态，切换为scash'
            scash
        fi
    else
        echo '未检测到qli-runner运行，尝试重启qli-Client'
        systemctl is-active --quiet scash && systemctl stop --no-block scash
        [ "$(pgrep SRBMiner-MULTI)" ] && kill `pgrep SRBMiner-MULTI`
        [ "$(pgrep qli-Client)" ] && kill $(pgrep qli-Client)
    fi
  else
    echo 'qli-runner 运行中'
    systemctl is-active --quiet scash && systemctl stop --no-block scash
    [ "$(pgrep SRBMiner-MULTI)" ] && kill `pgrep SRBMiner-MULTI`
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
}
function task_10_minutes(){
  i=0
  # 清理日志
  cat /dev/null > /var/log/qli.log
}
function main() {
  config_data=`jq ".Settings.alias = \"$minerAlias\"" /q/appsettings.json`
  echo $config_data | jq . > /q/appsettings.json
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
function scash() {
    systemctl is-enabled --quiet ore && systemctl disable ore
    systemctl is-active --quiet ore && systemctl stop --no-block ore
    if [ ! -f "/opt/scash/SRBMiner-MULTI" ]; then
        wget -O- https://raw.githubusercontent.com/chuben/script/main/scash.sh | bash
        systemctl start scash
    else
        systemctl start scash
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
