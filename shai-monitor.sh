#!/bin/bash
DIR="/opt/shai"

function switch() {
    echo "节点运行异常，当前矿池：$POOL_URL"
    echo "尝试切换"

    NEW_POOL_URL=''
    us=$(curl -s -o /dev/null -w "%{http_code}" 'https://us.svip.one/miner?address=sh1qn2mk4zymvk0z7ryly9p47yexupc9fs90q6ev6q')
    if [ "$us" -eq 200 ]; then
        NEW_POOL_URL="wss://shai-us.svip.one"
    fi

    if [ -z "$NEW_POOL_URL" ]; then
        jp=$(curl -s -o /dev/null -w "%{http_code}" 'https://jp.svip.one/miner?address=sh1qn2mk4zymvk0z7ryly9p47yexupc9fs90q6ev6q')
        if [ "$jp" -eq 200 ]; then
            NEW_POOL_URL="wss://shai-jp.svip.one"
        fi
    fi

    if [ -z "$NEW_POOL_URL" ]; then
        de=$(curl -s -o /dev/null -w "%{http_code}" 'https://de.svip.one/miner?address=sh1qn2mk4zymvk0z7ryly9p47yexupc9fs90q6ev6q')
        if [ "$de" -eq 200 ]; then
            NEW_POOL_URL="wss://shai-de.svip.one"
        fi
    fi

    if [ "$NEW_POOL_URL" == "$POOL_URL" ]; then
        echo "无需切换"
    elif [ "$NEW_POOL_URL" ]; then
        sed -i "/POOL_URL=/d" $DIR/.env
        echo "POOL_URL=$NEW_POOL_URL" >>$DIR/.env
        systemctl restart shai
        echo "切换完成"
        echo "当前矿池 $NEW_POOL_URL"
    else
        echo "切换失败，没有发现可用的矿池"
    fi

}

while true; do
    source $DIR/.env
    if [ "$(tail -20 $DIR/shai.log | grep 'Failed to connect will retry')" ]; then
        switch
    elif [ "$(tail -20 $DIR/shai.log | grep 'Hash rate: 0 hashes/secon')" ]; then
        switch
    else
        [ "$POOL_URL" != "wss://shai-us.svip.one" ] && switch
        echo "状态正常"
    fi
    sleep 60
done
