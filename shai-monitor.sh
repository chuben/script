#!/bin/bash
DIR="/opt/shai"

function switch() {
    source $DIR/.env
    echo "节点运行异常，当前矿池：$POOL_URL"
    echo "尝试切换"
    de=$(curl -s -o /dev/null -w "%{time_total}\n%{http_code}" 'https://de.benpool.top/miner?address=sh1qn2mk4zymvk0z7ryly9p47yexupc9fs90q6ev6q')
    us=$(curl -s -o /dev/null -w "%{time_total}\n%{http_code}" 'https://us.benpool.top/miner?address=sh1qn2mk4zymvk0z7ryly9p47yexupc9fs90q6ev6q')
    jp=$(curl -s -o /dev/null -w "%{time_total}\n%{http_code}" 'https://jp.benpool.top/miner?address=sh1qn2mk4zymvk0z7ryly9p47yexupc9fs90q6ev6q')
    sg=$(curl -s -o /dev/null -w "%{time_total}\n%{http_code}" 'https://www.benpool.top/miner?address=sh1qn2mk4zymvk0z7ryly9p47yexupc9fs90q6ev6q')

    de_time=$(echo $de | awk '{print $1}')
    de_http_code=$(echo $de | awk '{print $2}')
    us_time=$(echo $us | awk '{print $1}')
    us_http_code=$(echo $us | awk '{print $2}')
    jp_time=$(echo $jp | awk '{print $1}')
    jp_http_code=$(echo $jp | awk '{print $2}')
    sg_time=$(echo $sg | awk '{print $1}')
    sg_http_code=$(echo $sg | awk '{print $2}')

    [ "$de_http_code" -eq 200 ] && echo "$de_time wss://shai-de.benpool.top" >/tmp/bc
    [ "$us_http_code" -eq 200 ] && echo "$us_time wss://shai-us.benpool.top" >>/tmp/bc
    [ "$jp_http_code" -eq 200 ] && echo "$jp_time wss://shai-jp.benpool.top" >>/tmp/bc
    [ "$sg_http_code" -eq 200 ] && echo "$sg_time wss://shai.benpool.top" >>/tmp/bc

    NEW_POOL_URL="$(sort -n /tmp/bc | tail -1 | awk '{print $2}')"
    sed -i "/POOL_URL=/d" $DIR/.env
    echo "POOL_URL=$NEW_POOL_URL" >>$DIR/.env
    systemctl restart shai
    echo "切换完成"
    echo "当前矿池 $NEW_POOL_URL"
}

while true; do
    if [ "$(tail -20 $DIR/shai.log | grep 'Failed to connect will retry')" ]; then
        switch
    elif [ "$(tail -20 $DIR/shai.log | grep 'Hash rate: 0 hashes/secon')" ]; then
        switch
    else
        echo "状态正常"
    fi
    sleep 60
done
