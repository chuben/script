#!/bin/bash
while [[ $# -ge 1 ]]; do
  case $1 in
  -u | --username)
    shift
    username="$1"
    shift
    ;;
  -p | --password)
    shift
    password="$1"
    shift
    ;;
  -P | --port)
    shift
    port="$1"
    shift
    ;;
  *)
    if [[ "$1" != 'error' ]]; then echo -ne "\nInvaild option: '$1'\n\n"; fi
    echo -ne $help_info
    exit 1
    ;;
  esac
done

[ -z "$username" ] || [ -z "$password" ] || [ -z "$port" ] && exit 1

bash <(wget -qO- -o- https://git.io/v2ray.sh)
v2ray del
v2ray add socks $port $username $password