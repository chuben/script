#!/bin/bash
set -e

wget https://download.mikrotik.com/routeros/7.20.1/chr-7.20.1.img.zip -O chr.img.zip

gunzip -c chr.img.zip > chr.img

echo u > /proc/sysrq-trigger

ROOT_DISK=$(lsblk -no PKNAME "$(df / | awk 'NR==2{print $1}')")

[ -z "$ROOT_DISK" ] && exit

dd if=chr.img bs=1024 of=/dev/$ROOT_DISK

reboot