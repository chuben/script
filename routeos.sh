#!/bin/bash
set -e

[ -z "$1" ] && exit || PSWD=$1

wget https://download.mikrotik.com/routeros/7.20.1/chr-7.20.1.img.zip -O chr.img.zip

gunzip -c chr.img.zip > chr.img

mount -o loop,offset=33571840 chr.img /mnt

NET_IF=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')

NET_IP=$(ip addr show $NET_IF | awk '/global/{print $2;exit}')

NET_GW=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="via"){print $(i+1); exit}}')

[ -z "$NET_IP" ] && exit
[ -z "$NET_GW" ] && exit

cat > /mnt/rw/autorun.scr <<EOF
/ip address add address=$NET_IP interface=ether1
/ip route add gateway=$NET_GW
/user add name=ops group=full password=$PSWD
/user remove admin
/ip service disable telnet
/ip service disable ftp
/ip service disable www
/ip service disable api
/ip service disable api-ssl
/ip service disable ssh
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
EOF

umount /mnt

echo u > /proc/sysrq-trigger

ROOT_DISK=$(lsblk -no PKNAME "$(df / | awk 'NR==2{print $1}')")

[ -z "$ROOT_DISK" ] && exit

dd if=chr.img bs=1024 of=/dev/$ROOT_DISK

reboot