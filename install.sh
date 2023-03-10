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

setup_dns() {
    echo "Add the following DNS record:"
    echo "Type: A From: $DOMAIN Value: Your IP"
    echo "Add the following DNS record to ArvanCloud:"
    echo "Type: CNAME From: $DOMAIN_CDN Value: $DOMAIN Protocol: Default"
}

server_initial_setup() {
    echo_run "ln -fs /usr/share/zoneinfo/Asia/Tehran /etc/localtime"
    echo_run "dpkg-reconfigure -f noninteractive tzdata"
    echo_run "apt update -y"
    echo_run "apt upgrade -y"
    echo_run "apt dist-upgrade -y"
    echo_run "apt autoremove -y"
    echo_run "sleep 5"
    echo_run "reboot"
}

install_ssl() {
    echo_run "mkdir -p ~/docker/xui/"
    echo_run "apt install certbot docker.io docker-compose -y"
    echo_run "certbot certonly --email $CERTBOT_EMAIL -d $DOMAIN -d $DOMAIN_CDN --standalone --agree-tos --redirect --noninteractive"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/fullchain.pem ~/docker/xui/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/privkey.pem ~/docker/xui/"
}

install_xui() {
    echo_run "cp $PROJECT_PATH/docker-compose.yaml ~/docker/xui/"
    echo_run "cd ~/docker/xui/"
    echo_run "docker-compose up -d"
}

install_nginx() {
    echo_run "apt install nginx -y"
    echo_run "cp $PROJECT_PATH/x-ui.conf /etc/nginx/sites-available/x-ui.conf"
    echo_run "ln -s /etc/nginx/site-available/x-ui.conf /etc/nginx/site-enabled/"
    echo_run "nginx -t"
    echo_run "service nginx restart"
}

config_web_panel() {
    echo "Panel: https://`curl -s ifconfig.me`:54321"
    echo "UN: admin"
    echo "PW: admin"
    echo "Change xray Status to its latest version"
    echo "Panel Setting -> Panel Configuration -> Change port to 7701"
    echo "Panel Setting -> Panel Configuration -> Panel certificate public key file path: /root/cert/cert.crt"
    echo "Panel Setting -> Panel Configuration -> Panel certificate key file path: /root/cert/private.key"
    echo "Panel Setting -> User Setting -> Change password to `apg -n 1 -a 0`"
    echo "Panel Setting -> Other Setting -> Change timezone to Asia/Tehran"
    echo "Save and Restart"
    echo "Open panel at https://$DOMAIN:7071"
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
    echo "public key file path: /root/cert/cert.crt"
    echo "key file path: /root/cert/private.key"
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
    echo "======================"
    echo "Add a user and add scan the QR Code"
    echo "Duplicate the profile"
    echo "In the second profile replace $DOMAIN with $DOMAIN_CDN and 2087 with 443"
}

setup_arvan_cdn() {
    echo "Turn CDN On"
    echo "HTTPS Settings: Enable + Wait till certificate get released"
    echo "HTTPS Protocol: Automatic"
}

install_ocserv() {
    echo_run "apt install build-essential pkg-config nettle-dev gnutls-bin libgnutls28-dev libprotobuf-c1 libev-dev libreadline-dev -y"
    echo_run "apt autoremove -y"
    echo_run 'echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'
    echo_run "sysctl -p"
    echo_run "mkdir /etc/ocserv"
    echo_run "certtool --generate-dh-params --outfile /etc/ocserv/dh.pem"
    echo_run "cd /tmp"
    echo_run "wget https://www.infradead.org/ocserv/download/ocserv-1.1.6.tar.xz"
    echo_run "tar xvf ocserv-1.1.6.tar.xz"
    echo_run "cd ocserv-1.1.6/"
    echo_run "./configure --sysconfdir=/etc/ && make && make install"
    echo_run "cd $PROJECT_PATH"
    echo_run "rm -rf ocserv-1.1.6/ ocserv-1.1.6.tar.xz"
    echo_run "ocpasswd -c /etc/ocserv/ocpasswd $OCSERVUSER"
    echo_run "cp $PROJECT_PATH/ocserv.conf /etc/ocserv/ocserv.conf"
    echo_run 'echo "server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem" >> /etc/ocserv/ocserv.conf'
    echo_run 'echo "server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem" >> /etc/ocserv/ocserv.conf'
    echo_run "cp $PROJECT_PATH/ocserv.service /lib/systemd/system/ocserv.service"
    echo_run "sudo systemctl daemon-reload"
    echo_run "sudo systemctl start ocserv"
    echo_run "sudo systemctl enable ocserv"
}

setup_ocserv_iptables() {
    echo_run "iptables -A FORWARD -s 172.16.0.0/255.240.0.0 -j ACCEPT"
    echo_run "iptables -A FORWARD -s 10.0.0.0/255.0.0.0 -j ACCEPT"
    echo_run "iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT"
    echo_run "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
    echo_run "iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS  --clamp-mss-to-pmtu"
    echo_run "apt install iptables-persistent -y"
}

install_namizun() {
    echo_run "apt install proxychains -y"
    echo_run "ssh -NfD 9050 $SSHPROXY"
    echo_run "sudo curl https://raw.githubusercontent.com/malkemit/namizun/master/else/setup.sh | sudo proxychains bash"
}

ACTIONS=(
    setup_dns
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
