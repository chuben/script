#!/bin/bash

[ "$1" ] && KEY="$1" || exit 1
encrypted_string='''U2FsdGVkX18o74OI/sORrab9NQbM1K4ZMzgE8ZGcikgTRBvieHrIrSgYHLxJFi52
qHekrxdmsWw3I5zZ+leywsrxoYOzlYyAtN0QuDy9gKKj8IVbo4/iAZ+lT2j/mzAr
UEmw+46NwHJj0y7pjTeZhjtWRc4gBapy0sLXmWSadM2RdH5Z+tnc3jlAz8XiXsWM
SUBm5QSku5ghPNG/kuWOtL7XloSTEmCGFNPrajWNC+rZUGCSXUUZoJr7ky4ceODS
6iSjF7FRA/B0CPqHPlVIKvl1IVtClg71CZc7Pcq/LZeFcI9MRbgQ4pFCQpJyznb4
OO2dxgt9q1qbjCEU++wHoDJ0FgIUeFkONHkyWxh3K34o8eIpZs2kCBJN/Bnk7fK3
d1RPAAF2vXO6VabzxeIKiekhSL1yqSHsCOftX39quxi85rIVmrCONL0j8Qc8ggKF
f+sBiigBLfHqzjG56POPS1bkdnWtwtYmnsJYln2EUHS487+y/kqPThOJsTdsk1Jg
OykvkEdeWanvoG4UMpyrmsq2avUJcEFAzfK9gqtMtk79x3h9ptQ6x+TBM05b2eDd
vixd6oeZ0dAXZQrLODfak4naTt8P1GXAGfWVILRlP9Pr+wj2RL/UXqqKvrfl5qa6
uDmiQoztQdKb9PKwJC3UHFtDuWEWkmTV3uETLZakDDjcC4voGXZg40PaO9Imtyoy
4nte6UaM83mLuVyvD3Ap6A=='''

apt-get update && apt-get install -y unzip curl

apt-get update -qq
apt-get install -y -qq unzip curl


bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)

rm -rf /etc/sing-box/conf/*

echo "$encrypted_string" | openssl enc -d -aes-256-cbc -base64 -pass pass:"$KEY" > /etc/sing-box/conf/VLESS-HTTP2-REALITY-5443.json 2>/dev/null

systemctl enable sing-box
systemctl restart sing-box