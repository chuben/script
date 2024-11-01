#!/bin/bash
source /q/install.conf
[ -z "$accessToken" ] && accessToken="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJJZCI6IjFlMjIzYmU0LTFjNmMtNGJlZS1iZjdlLTc3MDg1NjJhYWNlNCIsIk1pbmluZyI6IiIsIm5iZiI6MTcyNTQ5NjU2NiwiZXhwIjoxNzU3MDMyNTY2LCJpYXQiOjE3MjU0OTY1NjYsImlzcyI6Imh0dHBzOi8vcXViaWMubGkvIiwiYXVkIjoiaHR0cHM6Ly9xdWJpYy5saS8ifQ.VaAgWKUvqo5hM_LPYX8NuDZkkCe2lR_kKoYS_9D_w16iQr7kCzEhmydeUULIhbeQauTOY2iw0EaiZyMCvAXSIu2k-4PzTyWMJvmEZATS_eaoahGzAwfj1-j7peLAztknDuA-8SmsNxgBwo_h4th0MQeJZpeixDxwZmDZbCMbSJG7U3frR24B9C1usPQ87ZRv3XES31F4nzc1GddsSKpPD_Nj1YYxyjgBrBRdgc1I8awhEAtOn84beSTOpx3CmvWBBOIz8EH9Qh9k2tsR1XIjuSvUPSGUMkaxHvTjPeHQ3EBqySmPzmBSXM7tjc0GJ1826yBiN9VB7V41xWV4UpNSew"

net_version=$(bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh) --version)
script_version=$(/q/qli-Service.sh -v)
new_version=$(echo -e "$net_version\n$script_version" | sort | tail -1)
if [ "$new_version" != "$script_version" ]; then
    echo "开始更新脚本"
    nohup bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh) --access-token $accessToken --install >>~/install.log &
else
    echo "脚本无需更新 $script_version"
    net_client_version="$(wget -T 3 -t 2 -qO- https://github.com/qubic-li/client/raw/main/README.md | grep '| Linux |' | awk -F '|' '{print $4}' | grep -v beta | tail -1 | xargs)"
    local_client_version=$(/q/qli-Client --version | awk '{print $3}')
    client_version=$(echo -e "$local_client_version\n$net_client_version" | sort | tail -1)
    if [ "$client_version" != "$local_client_version" ]; then
        echo "开始更新客户端"
        nohup bash <(wget -qO- https://raw.githubusercontent.com/chuben/script/main/qli-monitor.sh) --access-token $accessToken --install >>~/install.log &
    else
        echo "客户端无需更新 $client_version"
    fi
fi

version=$(curl -sL https://raw.githubusercontent.com/xintai6660707/ore-mine-pool/main/README.md | grep 'released' | head -1 | awk '{print $2}' | xargs)
localversion=$(/opt/ore/ore-pool-cli --version | awk '{print $2}')
newversion=$(echo -e "$localversion\n$version" | sed "s/v//g" | sort | tail -1)
if [ "$localversion" == "1.1.0" ]; then
    wget -O- https://raw.githubusercontent.com/chuben/script/main/ore.sh | bash
fi
if [ "$localversion" != "$newversion" ]; then
    wget -O- https://raw.githubusercontent.com/chuben/script/main/ore.sh | bash
fi
