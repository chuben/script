#!/bin/bash
source /q/install.conf
[ -z "$accessToken" ] && accessToken="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJJZCI6IjFlMjIzYmU0LTFjNmMtNGJlZS1iZjdlLTc3MDg1NjJhYWNlNCIsIk1pbmluZyI6IiIsIm5iZiI6MTczMTQ1NTc2OSwiZXhwIjoxNzYyOTkxNzY5LCJpYXQiOjE3MzE0NTU3NjksImlzcyI6Imh0dHBzOi8vcXViaWMubGkvIiwiYXVkIjoiaHR0cHM6Ly9xdWJpYy5saS8ifQ.dXJZmcf-eDub5aJk60r7tjzfwNG54fq7hNWpkdf1Uu07DRccrR_6nihAESOBklCvSHZR6qM3HT8ElNUXH5fLdzMIfYoSg8eETGKK_2wXlyar_4bH-8JZwfC_U48SKssJTQfYoR5FwrrM4MBKm9YI9EjgwTCOeMORoNtw8QkImItzm7FKol3l6DJT5NYkZbz8uHAfaIyMgPEmNUEOO2z_WKQeDryhlGekbo2YfTirDxtzC78kLpGPVDnFsWpCJ_sJOVC5HqdipnAxEoqpHuzj-YHdAaqfkf9-SJt1ZZzy_DrgRBjlsKCm2KrPg3EacCox77dG0z_iu0SyyC5zp1NWqQ"

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