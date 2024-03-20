#!/bin/bash

help_info=" Usage:\nbash $(basename $0)\t-t/--access-token [\033[33m\033[04m矿池token\033[0m]\n\t\t\t-id/--payout-id [\033[04mpayout id\033[0m]\n\t\t\t-a/--miner-alias [\033[33m\033[04mminer alias\033[0m]\n"

ip="$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/public-ipv4)"

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }

function install() {
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
    echo -e "accessToken=$accessToken\npayoutId=$payoutId\nminerAlias=$minerAlias\npushUrl=$pushUrl" > /q/env
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
function check_solutions() {
    last_status="$(tail -1 /var/log/qli.log | awk '{print $2, $7}')"
    log_time="$(echo $last_status | awk -F ':' '{print $1$2}')"
    now_time="$(date | awk '{print $4}' | awk -F ':' '{print $1$2}')"
    [ "$now_time" -ne "$log_time" ] && systemctl restart qli && return
    old_solutions="$(tail -1 /q/solutions)"
    [ -z "$old_solutions" ] && old_solutions='0/0'
    new_solutions="$(echo $last_status | awk '{print $2}')"
    echo "$new_solutions" >/q/solutions
    [ "$old_solutions" == "$new_solutions" ] && systemctl restart qli && return
}
function update() {
    echo '' >/var/log/qli.log
    wget -qO- https://dl.qubic.li/downloads/qli-Client-${1}-Linux-x64.tar.gz | tar -zxf - -C /tmp/
    rm /q/*.lock
    [ -f "/q/qli-runner" ] && rm /q/qli-runner
    [ -f "/q/qli-processor" ] && rm /q/qli-processor
    mv -f /tmp/qli-Client /q/.
    systemctl restart qli
}
function check_update() {
    remote_version="$(wget -T 3 -t 2 -qO- https://github.com/qubic-li/client/raw/main/README.md | grep '| Linux |' | awk -F '|' '{print $4}' | tail -1 | xargs)"
    [ -z "$remote_version" ] && echo "版本获取失败" && return
    local_version="$(/q/qli-Client --version | awk '{print $3}')"
    [ -z "$local_version" ] && local_version='1.0'
    if version_gt $remote_version $local_version; then
        update $remote_version
    else
        echo '没有发现新版本'
    fi
}
function check_run() {
    [ "$freq" -ge 10 ] && install
    [ ! -f "/q/appsettings.json" ] && install
    [ ! -f "/q/qli-Client" ] && install
    [ ! -f "/q/qli-Service.sh" ] && install
    if [ ! $(pgrep qli-Client) ]; then
        cd /q && nohup /q/qli-Client -service >>/var/log/qli.log &
        let freq++
        sleep 10
        push_info
    fi
}
function push_info(){
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
function main() {
    [ $(pgrep qli-Client) ] && push_info
    s=0
    u=0
    p=0
    freq=0
    while true; do
        let s++ && let u++ && let p++
        # 每分钟检查一次程序
        [ ! $(pgrep qli-Client) ] && check_run || freq = 0
        # 每10分钟上传一次状态
        if [ "$p" -ge 10 ]; then
            p=0
            push_info
        fi
        # 每12小时检查一次出块情况
        if [ "$s" -ge 720 ]; then
            s=0
            check_solutions
        fi
        # 每天检查一次更新
        if [ "$u" -ge 1440 ]; then
            u=0
            check_update
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
      install
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