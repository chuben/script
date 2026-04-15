#!/bin/bash

[ "$1" ] && KEY="$1" || exit 1
encrypted_string='''U2FsdGVkX18bjI2p+N8Q2cb6lmB/kM7r/jNbprgmPM0bFDmUcy7142fgxrIS275R
s8t2GsmfWNBBXN1efzXFIiLuqj8pByInkxNxzdfFUjSQ3FbU77tE/nxl4e3kJz3i
f7YSrBL7D1veQGxrGkqE5cd3rdfhSxIVWJGOSj39dpcr0+pUiqMewta9C/reIgy9
2vpa+tTEBJn4qbkYg5iaBLmOD2bm30StdyL0gljUVK0wcQDa27SuAHOmfM3OpoBE
7i8mfUR2Sx3WGdk+HsEXWufV/7wna23eaQzt8h4eIkcUHl8AKDVI840jOumu62mR
CpFnPq36VD0bagGCcjvPdZAVrvKBOcMOihYZvjF8ph2ud2q2JnmJvK1+7y3DErw5
wj55AmrNU5j6H9l9wMQW5JPj+X0kaWq/D5Rso7U9oNV5gv9hoPixG8grHuKA7HmB
mJern0v1uAmjG8Lj/V1VRMS2T/MeEmfgTWxPGOxyim1rxPJfXwaYuLKpSUbBGrTe
SheYXs01k2P0GHQ8YKZUy3dYA7F3iH8mgnImiXQjKO63zkIxMcMvPSfJq33+k5N6
QRckxx78bm/KhERg6cTmtzdo6NguJCcISxl75qquBGHKi3XdQAMPko0ynB7GsX0i
3L/nnsRH7qTyUX/idz1toHIXDy0nAociYn2friysQdW7rLbEhiF4hSZO4hf3yYsu
N5rPOUd6031t/q4F0hudX42AucQBZeFE4ki5mrwS4MhthzAHYy2plV0/4nzZpLdR
r7ZGLhX1/5yrLe79DULpBUF8CsO4egHc829wQMrnHAO4jeFBXlE3j8fwnJfxFwZZ
0gLXNiYM1Qiu8Vh0eQd02nP8LW8pKKsg5kkDbnrtctO+5D9s0AtcGCU1tnCsCw6D
HZyI7TLPpX4Yc02kG6nsp5zzXdtc/did3qkz973XbuJ19aU4kr2uyXlNBsm8DL/A
/GYMqzQp+VBT0pvnT8uqR0nocI0F9OpC7O1t/h7jT7Wdukh7E2Xw02BjyfsIqGIZ
jKcgGt5HoFh+nvNfezdnoSoZzjPReli/wMmbTpR9HmQ='''

set -e
apt-get update && apt-get install -y unzip curl

apt-get update -qq
apt-get install -y -qq unzip curl


bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

echo "$encrypted_string" | openssl enc -d -aes-256-cbc -base64 -pass pass:"$KEY" > /usr/local/etc/xray/config.json 2>/dev/null

systemctl enable xray
systemctl restart xray