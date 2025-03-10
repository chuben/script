#!/bin/bash

bash <(wget -qO- -o- https://git.io/v2ray.sh)

rm -rf /etc/v2ray/conf/*

echo '{
  "inbounds": [
    {
      "tag": "Socks5.json",
      "port": 29999,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "ip": "0.0.0.0"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ]
}' > /etc/v2ray/conf/Socks5.json

v2ray restart