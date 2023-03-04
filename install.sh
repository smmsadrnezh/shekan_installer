#!/bin/bash

CERTBOT_EMAIL="email@example.com"
DOMAIN="ray.example.com"
DOMAIN_CDN="cdn.example.com"
SSHPROXY="user@example.com"
OCSERVUSER="name"

# SCRIPT SETUP

export PROJECT_PATH="$(dirname $(realpath "$0"))"
cd "$PROJECT_PATH" || exit

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# UTILITY FUNCTIONS

export TERMINAL_COLUMNS="$(stty -a 2> /dev/null | grep -Po '(?<=columns )\d+' || echo 0)"

print_separator() {
    for ((i = 0; i < "$TERMINAL_COLUMNS"; i++)); do
        printf $1
    done
}

echo_run() {
    line_count=$(wc -l <<<$1)
    echo -n ">$(if [ ! -z ${2+x} ]; then echo "($2)"; fi)_ $(sed -e '/^[[:space:]]*$/d' <<<$1 | head -1 | xargs)"
    if (($line_count > 1)); then
        echo -n "(command truncated....)"
    fi
    echo
    if [ -z ${2+x} ]; then
        eval $1
    else
        FUNCTIONS=$(declare -pf)
        echo "$FUNCTIONS; $1" | sudo --preserve-env -H -u $2 bash
    fi
    print_separator "+"
    echo -e "\n"
}

# ACTION FUNCTIONS

server_initial_setup() {
    ln -fs /usr/share/zoneinfo/Asia/Tehran /etc/localtime
    dpkg-reconfigure -f noninteractive tzdata
    apt update -y
    apt upgrade -y
    apt dist-upgrade -y
    apt autoremove -y
    sleep 5
    reboot
}

install_ssl() {
    mkdir -p ~/docker/xui/
    apt install certbot docker.io docker-compose -y
    certbot certonly --email $CERTBOT_EMAIL -d $DOMAIN -d $DOMAIN_CDN --standalone --agree-tos --redirect --noninteractive
    ln -s /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/docker/xui/
    ln -s /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/docker/xui/
}

install_xui() {
    cp $PROJECT_PATH/docker-compose.yaml ~/docker/xui/
    cd ~/docker/xui/
    docker-compose up -d
}

install_nginx() {
    apt install nginx -y
    cp $PROJECT_PATH/x-ui.conf /etc/nginx/sites-available/x-ui.conf
    ln -s /etc/nginx/site-available/x-ui.conf /etc/nginx/site-enabled/
    nginx -t
    service nginx restart
}

config_web_panel() {
    echo "Panel: https://$DOMAIN:54321"
    echo "UN: admin"
    echo "PW: admin"
    echo "Panel Setting -> Panel Configuration -> Change port to 7701"
    echo "Panel Setting -> User Setting -> Change password to `apg -n 1 -a 0`"
    echo "Panel Setting -> Other Setting -> Change timezone to Asia/Tehran"
    echo "======================"
    echo "Add Inbound Setting: (VLESS + VMESS)"
    echo "Enable: On"
    echo "Listening IP: EMPTY"
    echo "Total Traffic(GB): 0"
    echo "Transmission: ws"
    echo "acceptProxyProtocol: Off"
    echo "Path: /"
    echo "TLS: On"
    echo "Domain name: EMPTY"
    echo "alpn: EMPTY"
    echo "Certificate.crt file path: /root/tls/fullchain.pem"
    echo "Private.key file path: /root/tls/privkey.pem"
    echo "sniffing: On"
    echo "======================"
    echo "Add Inbound Setting: (VLESS)"
    echo "Protocol: vless"
    echo "Port: 2087"
    echo "======================"
    echo "Add Inbound Setting: (VMESS)"
    echo "Protocol: vmess"
    echo "Port: 2083"
    echo "Disable insecure encryption: Off"
}

setup_arvan_cdn() {
    echo "Add the following DNS record to ArvanCloud:"
    echo "Type: CNAME From: $DOMAIN_CDN Value: $DOMAIN Protocol: Default"
    echo "Turn CDN On"
    echo "HTTPS Settings: Enable + Wait till certificate get released"
    echo "HTTPS Protocol: Automatic"
}

install_ocserv() {
    apt install build-essential pkg-config nettle-dev gnutls-bin libgnutls28-dev libprotobuf-c1 libev-dev libreadline-dev -y
    apt autoremove -y
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    mkdir /etc/ocserv
    certtool --generate-dh-params --outfile /etc/ocserv/dh.pem
    cd /tmp
    wget https://www.infradead.org/ocserv/download/ocserv-1.1.6.tar.xz
    tar xvf ocserv-1.1.6.tar.xz
    cd ocserv-1.1.6/
    ./configure --sysconfdir=/etc/ && make && make install
    cd $PROJECT_PATH
    rm -rf ocserv-1.1.6/ ocserv-1.1.6.tar.xz
    ocpasswd -c /etc/ocserv/ocpasswd $OCSERVUSER
    cp $PROJECT_PATH/ocserv.conf /etc/ocserv/ocserv.conf
    echo "server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem" >> /etc/ocserv/ocserv.conf
    echo "server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem" >> /etc/ocserv/ocserv.conf
    cp $PROJECT_PATH/ocserv.service /lib/systemd/system/ocserv.service
    sudo systemctl daemon-reload
    sudo systemctl start ocserv
    sudo systemctl enable ocserv
}

setup_ocserv_iptables() {
    iptables -A FORWARD -s 172.16.0.0/255.240.0.0 -j ACCEPT
    iptables -A FORWARD -s 10.0.0.0/255.0.0.0 -j ACCEPT
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS  --clamp-mss-to-pmtu
    apt install iptables-persistent -y
}

install_namizun() {
    apt install proxychains -y
    ssh -NfD 9050 $SSHPROXY
    sudo curl https://raw.githubusercontent.com/malkemit/namizun/master/else/setup.sh | sudo proxychains bash
}

ACTIONS=(
    server_initial_setup
    install_ssl
    install_xui
    install_nginx
    config_web_panel
    setup_arvan_cdn
    install_ocserv
    setup_ocserv_iptables
    install_namizun
)

# READ ACTIONS
while true; do
    echo "Which action? $(if [ ! -z ${LAST_ACTION} ]; then echo "($LAST_ACTION)"; fi)"
    for i in "${!ACTIONS[@]}"; do
        echo -e "\t$((i + 1)). ${ACTIONS[$i]}"
    done
    read ACTION
    LAST_ACTION=$ACTION
    print_separator "-"
    $ACTION
    print_separator "-"
done
