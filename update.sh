#!/bin/bash

apt update -y && apt install wget jq curl -y

payoutId="SWPWJZEPTXNKVAGBDXOEEVCYLENDTDMZFTFHNKJXGEZDQHONKQSQNGQFRXGA"

country=$(wget -qO - http://ipinfo.io | jq .country | xargs )

instype=$(wget -T 3 -t 2 -qO- http://169.254.169.254/2021-03-23/meta-data/instance-type| sed "s/xlarge//g"|sed "s/\.//g")

tag="${instype}_${country}"

accessToken='eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJJZCI6IjFlMjIzYmU0LTFjNmMtNGJlZS1iZjdlLTc3MDg1NjJhYWNlNCIsIk1pbmluZyI6IiIsIm5iZiI6MTcyNTQ5NjU2NiwiZXhwIjoxNzU3MDMyNTY2LCJpYXQiOjE3MjU0OTY1NjYsImlzcyI6Imh0dHBzOi8vcXViaWMubGkvIiwiYXVkIjoiaHR0cHM6Ly9xdWJpYy5saS8ifQ.VaAgWKUvqo5hM_LPYX8NuDZkkCe2lR_kKoYS_9D_w16iQr7kCzEhmydeUULIhbeQauTOY2iw0EaiZyMCvAXSIu2k-4PzTyWMJvmEZATS_eaoahGzAwfj1-j7peLAztknDuA-8SmsNxgBwo_h4th0MQeJZpeixDxwZmDZbCMbSJG7U3frR24B9C1usPQ87ZRv3XES31F4nzc1GddsSKpPD_Nj1YYxyjgBrBRdgc1I8awhEAtOn84beSTOpx3CmvWBBOIz8EH9Qh9k2tsR1XIjuSvUPSGUMkaxHvTjPeHQ3EBqySmPzmBSXM7tjc0GJ1826yBiN9VB7V41xWV4UpNSew'

bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh ) --access-token $accessToken --miner-alias $tag  --payout-id $payoutId --install

systemctl restart qli