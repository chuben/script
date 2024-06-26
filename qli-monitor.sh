#!/bin/bash
script_version='1.7'

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
  [ "$threads" -gt 8 ] && threads=$(expr $(nproc) - 1)
  [ -z "$accessToken" ] || [ -z "$payoutId" ] || [ -z "$minerAlias" ] || [ -z "$pushUrl" ] && source /q/install.conf
  [ -z "$accessToken" ] || [ -z "$payoutId" ] || [ -z "$minerAlias" ] || [ -z "$pushUrl" ] && exit
  version="$(wget -T 3 -t 2 -qO- https://github.com/qubic-li/client/raw/main/README.md | grep '| Linux |' | awk -F '|' '{print $4}' | grep -v beta | tail -1 | xargs)"
  [ -z "$version" ] && version='1.8.10'
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
  wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-update.sh >/q/update.sh
  chmod u+x /q/qli-Service.sh
  chmod u+x /q/update.sh
  chmod u+x /q/qli-Client
  chmod 664 /etc/systemd/system/qli.service
  systemctl daemon-reload
  systemctl enable --no-block qli.service
  systemctl start qli.service
  apt install cron -y
  echo '33 * * * * /q/update.sh' > /var/spool/cron/crontabs/root
  reboot
}
function qli_run() {
  [ "$(pgrep zoxx_rqiner)" ] && kill $(pgrep zoxx_rqiner)
  [ ! -f "/q/appsettings.json" ] && qli_install
  [ ! -f "/q/qli-Client" ] && qli_install
  [ ! -f "/q/qli-Service.sh" ] && qli_install

  # 如果runner未运行，杀死client
  if [ ! "$(pgrep qli-runner)" ]; then
    let z++
    [ "$(pgrep qli-Client)" ] && kill $(pgrep qli-Client)
  else
    z=0
  fi

  if [ ! "$(pgrep qli-Client)" ]; then
    cd /q && nohup /q/qli-Client -service >>/var/log/qli.log &
    let freq++
  else
    freq=0
  fi
}
function push_info_qli() {
  source /q/install.conf
  [ -z "$pushUrl" ] && return
  [ ! -f '/var/log/qli.log' ] && return
  name="$(cat /q/appsettings.json | jq .Settings.alias | xargs)"
  token="$(cat /q/appsettings.json | jq .Settings.accessToken | xargs)"
  [ -z "$ip" ] && ip=$(wget -T 3 -t 2 -qO- ifconfig.me)
  log_info=$(tail -1 /var/log/qli.log)
  solut=$(echo $log_info | awk '{print $7}' | awk -F '/' '{print $2}')
  its=$(echo $log_info | awk '{print $15}')
  version=$(/q/qli-Client --version |awk '{print $3}')
  epoch=$(echo $log_info | awk '{print $4}' | awk -F ':' '{print $2}')
  data='{}'
  data=$(jq --null-input --argjson data "$data" --arg name "$name" '$data + {$name}')
  data=$(jq --null-input --argjson data "$data" --arg ip "$ip" '$data + {$ip}')
  data=$(jq --null-input --argjson data "$data" --arg its "$its" '$data + {$its}')
  data=$(jq --null-input --argjson data "$data" --arg solut "$solut" '$data + {$solut}')
  data=$(jq --null-input --argjson data "$data" --arg version "$version" '$data + {$version}')
  data=$(jq --null-input --argjson data "$data" --arg token "$token" '$data + {$token}')
  data=$(jq --null-input --argjson data "$data" --arg epoch "$epoch" '$data + {$epoch}')
  for i in `seq 1 5`; do
    resp=`curl -sLd "$data" -X POST $pushUrl`
    echo $resp | jq .message
    [ "$(echo $resp | jq .code)" -eq 20000 ] && break || sleep 5
  done
}
function push_info_zoxx() {
  source /q/install.conf
  [ -z "$pushUrl" ] && return
  name="$(jq .Settings.alias /q/appsettings.json | xargs)"
  token="$(jq .Settings.accessToken /q/appsettings.json | xargs)"
  [ -z "$ip" ] && ip=$(wget -T 3 -t 2 -qO- ifconfig.me)
  log_info=$(systemctl status qli | tail -1)
  solut=$(echo $log_info | awk '{print $20}')
  its=$(echo $log_info | awk '{print $16}')
  version="zoxx"
  epoch=$(wget -qO - https://pooltemp.qubic.solutions/info | jq .epoch)
  data='{}'
  data=$(jq --null-input --argjson data "$data" --arg name "$name" '$data + {$name}')
  data=$(jq --null-input --argjson data "$data" --arg ip "$ip" '$data + {$ip}')
  data=$(jq --null-input --argjson data "$data" --arg its "$its" '$data + {$its}')
  data=$(jq --null-input --argjson data "$data" --arg solut "$solut" '$data + {$solut}')
  data=$(jq --null-input --argjson data "$data" --arg version "$version" '$data + {$version}')
  data=$(jq --null-input --argjson data "$data" --arg token "$token" '$data + {$token}')
  data=$(jq --null-input --argjson data "$data" --arg epoch "$epoch" '$data + {$epoch}')
  for i in `seq 1 5`; do
    resp=`curl -sLd "$data" -X POST $pushUrl`
    echo $resp | jq .message
    [ "$(echo $resp | jq .code)" -eq 20000 ] && break | sleep 5
  done
}
function zoxx_run() {
  [ "$(pgrep qli-Client)" ] && kill $(pgrep qli-Client)
  [ "$(pgrep qli-runner)" ] && kill $(pgrep qli-runner)
  zoxx_install
  if [ ! "$(pgrep zoxx_rqiner)" ]; then
    source /q/install.conf
    [ -z "$threads" ] || [ -z "$payoutId" ] || [ -z "$minerAlias" ] && qli_install
    nohup /q/zoxx_rqiner -t $threads -l $minerAlias -i $payoutId >>/var/log/qli.log &
  else
    zfreq=0
  fi
}
function zoxx_install() {
  case $(uname -m) in
  armv5*) ARCH="aarch64" ;;
  armv6*) ARCH="aarch64" ;;
  armv7*) ARCH="aarch64" ;;
  aarch64) ARCH="aarch64" ;;
  x86) ARCH="x86" ;;
  x86_64) ARCH="x86" ;;
  i686) ARCH="x86" ;;
  i386) ARCH="x86" ;;
  *) echo -e "\033[31m不支持此系统\033[0m" && exit 1 ;;
  esac
  file_name="rqiner-${ARCH}"
  version=$(curl -sL https://github.com/Qubic-Solutions/rqiner-builds/releases | grep 'Qubic-Solutions/rqiner-builds/releases/tag' | head -1 | awk '{print $7}' | xargs | awk -F '/' '{print $6}')
  #install
  [ ! -d "/q" ] && mkdir /q
  [ -f "/q/zoxx_rqiner" ] && rm -rf /q/zoxx_rqiner
  cd /q/
  curl -o /q/zoxx_rqiner -sL https://github.com/Qubic-Solutions/rqiner-builds/releases/download/${version}/${file_name}
  chmod u+x /q/zoxx_rqiner
}
function check_run() {
  [ "$z" -ge 5 ] && pool='zoxx'
  echo "当前池为 $pool $z"

  # 如果有多个runner进程，杀死最久的那个
  [ "$(pgrep -c qli-runner)" -gt 1 ] && kill $(pgrep -o qli-runner)

  if [ "$pool" == "qli" ]; then
    check_nr_hugepages
    qli_run
  elif [ "$pool" == "zoxx" ]; then
    zoxx_run
  fi
}
function check_qli_status() {
  if [ "$pool" == "zoxx" ]; then
    http_code="$(curl -sIL -w "%{http_code}" -o /dev/null https://mine.qubic.li/)"
    [ "$http_code" -ne 503 ] && [ "$http_code" -ne 504 ] && pool='qli' && z=0
  fi
}
function task_hour(){
  ii=0
  check_qli_status
  epoch=$(tail -1 /var/log/qli.log | awk '{print $4}' | awk -F ':' '{print $2}')
  [ -f "/q/stats.${epoch}.lock" ] && sed -i "s/:true/:false/g" /q/stats.${epoch}.lock
}
function check_alias(){
  ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"
  [ -z "`jq .Settings.alias /q/appsettings.json | grep $ip`" ] && nohup bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/update.sh) >> ~/install.log &
}
function task_10_minutes(){
  i=0
  # 每10分钟上传一次状态
  # [ "$pool" == "qli" ] && push_info_qli || push_info_zoxx
  # 清理日志
  check_alias
  cat /dev/null > /var/log/qli.log
}
function main() {
  i=0
  ii=0
  freq=0
  z=0
  zfreq=0
  pool='qli'
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
  -P | --push_info)
    shift
    [ "$(pgrep qli-runner)" ] && push_info_qli || push_info_zoxx
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
