#!/bin/bash
if [ -z "$1" ]; then
    echo "❌ 用法: $0 <解密密钥>"
    exit 1
fi

KEY="$1"

if readlink /proc/$$/exe | grep -q "dash"; then
	echo 'This installer needs to be run with "bash", not "sh".'
	exit
fi

read -N 999999 -t 0.001

if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	group_name="nogroup"
elif [[ -e /etc/debian_version ]]; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
	group_name="nogroup"
elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
	os="centos"
	os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
	group_name="nobody"
elif [[ -e /etc/fedora-release ]]; then
	os="fedora"
	os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
	group_name="nobody"
else
	echo "This installer seems to be running on an unsupported distribution.
Supported distros are Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS and Fedora."
	exit
fi

if [[ "$os" == "ubuntu" && "$os_version" -lt 2204 ]]; then
	echo "Ubuntu 22.04 or higher is required to use this installer.
This version of Ubuntu is too old and unsupported."
	exit
fi

if [[ "$os" == "debian" ]]; then
	if grep -q '/sid' /etc/debian_version; then
		echo "Debian Testing and Debian Unstable are unsupported by this installer."
		exit
	fi
	if [[ "$os_version" -lt 11 ]]; then
		echo "Debian 11 or higher is required to use this installer.
This version of Debian is too old and unsupported."
		exit
	fi
fi

if [[ "$os" == "centos" && "$os_version" -lt 9 ]]; then
	os_name=$(sed 's/ release.*//' /etc/almalinux-release /etc/rocky-release /etc/centos-release 2>/dev/null | head -1)
	echo "$os_name 9 or higher is required to use this installer.
This version of $os_name is too old and unsupported."
	exit
fi

# Detect environments where $PATH does not include the sbin directories
if ! grep -q sbin <<< "$PATH"; then
	echo '$PATH does not include sbin. Try using "su -" instead of "su".'
	exit
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "This installer needs to be run with superuser privileges."
	exit
fi

if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
	echo "The system does not have the TUN device available.
TUN needs to be enabled before running this installer."
	exit
fi

# Store the absolute path of the directory where the script is located
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# Detect some Debian minimal setups where neither wget nor curl are installed
if ! hash wget 2>/dev/null && ! hash curl 2>/dev/null; then
	echo "Wget is required to use this installer."
	apt-get update
	apt-get install -y wget
fi
clear
echo 'Welcome to this OpenVPN road warrior installer!'
# If system has a single IPv4, it is selected automatically. Else, ask the user
if [[ $(ip -4 addr | grep inet | grep -v tun | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
	ip=$(ip -4 addr | grep inet | grep -v tun | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
else
	ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n 1p)
fi
# If $ip is a private IP address, the server must be behind NAT
if echo "$ip" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
	echo
	echo "This server is behind NAT. What is the public IPv4 address or hostname?"
	# Get public IP and sanitize with grep
	public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")
fi
# If system has a single IPv6, it is selected automatically
if [[ $(ip -6 addr | grep -c 'inet6 [23]') -eq 1 ]]; then
	ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}')
fi
# If system has multiple IPv6, ask the user to select one
if [[ $(ip -6 addr | grep -c 'inet6 [23]') -gt 1 ]]; then
	number_of_ip6=$(ip -6 addr | grep -c 'inet6 [23]')
	echo
	echo "Which IPv6 address should be used?"
	ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | nl -s ') '
	ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | sed -n 1p)
fi
echo
protocol=tcp
port="443"
client="client"
echo
echo "OpenVPN installation is ready to begin."
# Install a firewall if firewalld or iptables are not already available
if ! systemctl is-active --quiet firewalld.service && ! hash iptables 2>/dev/null; then
	if [[ "$os" == "centos" || "$os" == "fedora" ]]; then
		firewall="firewalld"
		# We don't want to silently enable firewalld, so we give a subtle warning
		# If the user continues, firewalld will be installed and enabled during setup
		echo "firewalld, which is required to manage routing tables, will also be installed."
	elif [[ "$os" == "debian" || "$os" == "ubuntu" ]]; then
		# iptables is way less invasive than firewalld so no warning is given
		firewall="iptables"
	fi
fi
# If running inside a container, disable LimitNPROC to prevent conflicts
if systemd-detect-virt -cq; then
	mkdir /etc/systemd/system/openvpn-server@server.service.d/ 2>/dev/null
	echo "[Service]
LimitNPROC=infinity" > /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
fi
if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
	apt-get update
	apt-get install -y --no-install-recommends openvpn openssl ca-certificates $firewall age
elif [[ "$os" = "centos" ]]; then
	dnf install -y epel-release
	dnf install -y openvpn openssl ca-certificates tar $firewall
else
	# Else, OS must be Fedora
	dnf install -y openvpn openssl ca-certificates tar $firewall
fi
# If firewalld was just installed, enable it
if [[ "$firewall" == "firewalld" ]]; then
	systemctl enable --now firewalld.service
fi
wget -qO /tmp/conf.tar.gz.age "https://raw.githubusercontent.com/chuben/script/main/conf.tar.gz.age"

ENC_AGE_SECRET_KEY="U2FsdGVkX1/kGblucAIThGngTkQrDOKJ5Zk5WhnJLbZ8sD63Z7vYkB/eLRQ/EDEk 99Pk1qZRb8de4oKRZ3+i1uLXgo1MlSrx09h32vpZRF75KGquHFn9uBAOA+qrjpe1"
AGE_SECRET_KEY=$(echo "$ENC_AGE_SECRET_KEY" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$KEY")

age -d -i <(echo "$AGE_SECRET_KEY") /tmp/conf.tar.gz.age | tar xz -C /etc/openvpn/server --strip-components=1

chown nobody:"$group_name" /etc/openvpn/server/crl.pem
# Without +x in the directory, OpenVPN can't run a stat() on the CRL file
chmod o+x /etc/openvpn/server/
# Generate server.conf
echo "local $ip
port $port
proto $protocol
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-crypt tc.key
topology subnet
server 10.8.0.0 255.255.255.0" > /etc/openvpn/server/server.conf
# IPv6
if [[ -z "$ip6" ]]; then
	echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server/server.conf
else
	echo 'server-ipv6 fddd:1194:1194:1194::/64' >> /etc/openvpn/server/server.conf
	echo 'push "redirect-gateway def1 ipv6 bypass-dhcp"' >> /etc/openvpn/server/server.conf
fi
echo 'ifconfig-pool-persist ipp.txt' >> /etc/openvpn/server/server.conf
# DNS
echo 'push "dhcp-option DNS 1.1.1.2"' >> /etc/openvpn/server/server.conf
echo 'push "dhcp-option DNS 1.0.0.2"' >> /etc/openvpn/server/server.conf
echo 'push "block-outside-dns"' >> /etc/openvpn/server/server.conf
echo "keepalive 10 120
user nobody
group $group_name
persist-key
persist-tun
verb 3
crl-verify crl.pem" >> /etc/openvpn/server/server.conf
if [[ "$protocol" = "udp" ]]; then
	echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf
fi
# Enable net.ipv4.ip_forward for the system
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn-forward.conf
# Enable without waiting for a reboot or service restart
echo 1 > /proc/sys/net/ipv4/ip_forward
if [[ -n "$ip6" ]]; then
	# Enable net.ipv6.conf.all.forwarding for the system
	echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-openvpn-forward.conf
	# Enable without waiting for a reboot or service restart
	echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
fi
if systemctl is-active --quiet firewalld.service; then
	# Using both permanent and not permanent rules to avoid a firewalld
	# reload.
	# We don't use --add-service=openvpn because that would only work with
	# the default port and protocol.
	firewall-cmd --add-port="$port"/"$protocol"
	firewall-cmd --zone=trusted --add-source=10.8.0.0/24
	firewall-cmd --permanent --add-port="$port"/"$protocol"
	firewall-cmd --permanent --zone=trusted --add-source=10.8.0.0/24
	# Set NAT for the VPN subnet
	firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip"
	firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip"
	if [[ -n "$ip6" ]]; then
		firewall-cmd --zone=trusted --add-source=fddd:1194:1194:1194::/64
		firewall-cmd --permanent --zone=trusted --add-source=fddd:1194:1194:1194::/64
		firewall-cmd --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
		firewall-cmd --permanent --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
	fi
else
	# Create a service to set up persistent iptables rules
	iptables_path=$(command -v iptables)
	ip6tables_path=$(command -v ip6tables)
	# nf_tables is not available as standard in OVZ kernels. So use iptables-legacy
	# if we are in OVZ, with a nf_tables backend and iptables-legacy is available.
	if [[ $(systemd-detect-virt) == "openvz" ]] && readlink -f "$(command -v iptables)" | grep -q "nft" && hash iptables-legacy 2>/dev/null; then
		iptables_path=$(command -v iptables-legacy)
		ip6tables_path=$(command -v ip6tables-legacy)
	fi
	echo "[Unit]
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=$iptables_path -w 5 -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip
ExecStart=$iptables_path -w 5 -I INPUT -p $protocol --dport $port -j ACCEPT
ExecStart=$iptables_path -w 5 -I FORWARD -s 10.8.0.0/24 -j ACCEPT
ExecStart=$iptables_path -w 5 -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$iptables_path -w 5 -t nat -D POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip
ExecStop=$iptables_path -w 5 -D INPUT -p $protocol --dport $port -j ACCEPT
ExecStop=$iptables_path -w 5 -D FORWARD -s 10.8.0.0/24 -j ACCEPT
ExecStop=$iptables_path -w 5 -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" > /etc/systemd/system/openvpn-iptables.service
	if [[ -n "$ip6" ]]; then
		echo "ExecStart=$ip6tables_path -w 5 -t nat -A POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
ExecStart=$ip6tables_path -w 5 -I FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
ExecStart=$ip6tables_path -w 5 -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$ip6tables_path -w 5 -t nat -D POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
ExecStop=$ip6tables_path -w 5 -D FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
ExecStop=$ip6tables_path -w 5 -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" >> /etc/systemd/system/openvpn-iptables.service
	fi
	echo "RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/openvpn-iptables.service
	systemctl enable --now openvpn-iptables.service
fi
# If SELinux is enabled and a custom port was selected, we need this
if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$port" != 1194 ]]; then
	# Install semanage if not already present
	if ! hash semanage 2>/dev/null; then
			dnf install -y policycoreutils-python-utils
	fi
	semanage port -a -t openvpn_port_t -p "$protocol" "$port"
fi

systemctl enable --now openvpn-server@server.service
echo
echo "Finished!"