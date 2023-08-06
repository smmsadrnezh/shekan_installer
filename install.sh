#!/bin/bash

if [ ! -f ".env" ]; then
    echo ".env file does not exist."
    exit
fi

if ! grep -q "NEW_PASSWORD=" .env;then
    echo "export NEW_PASSWORD=\"`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`\"" >> .env
fi

source .env

# Varibales
export PUBLIC_IP=`curl -s ifconfig.me`
export REMARK_PREFIX=`echo $DOMAIN | cut -d '.' -f1`

# SCRIPT SETUP

export PROJECT_PATH="$(dirname $(realpath "$0"))"
cd "$PROJECT_PATH" || exit

export PROJECT_CONFIGS="$PROJECT_PATH/configs"

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

function gcf() {
    export GCF_ED='$'
    envsubst <$1
}

# ACTION FUNCTIONS

setup_dns() {
    echo "Add the following DNS record:"
    echo -e "\tType: A"
    echo -e "\tFrom: $DOMAIN"
    echo -e "\tValue: $PUBLIC_IP"
    echo -e "Add the following DNS record to ArvanCloud:"
    echo -e "\tType: CNAME"
    echo -e "\tFrom: $DOMAIN_CDN"
    echo -e "\tValue: $DOMAIN"
    echo -e "\tProtocol: Default"
}

server_initial_setup() {
    echo_run "ln -fs /usr/share/zoneinfo/Asia/Tehran /etc/localtime"
    echo_run "dpkg-reconfigure -f noninteractive tzdata"
    echo_run "apt update -y"
    echo_run "apt install -y apg tmux vim net-tools"
    echo_run "apt full-upgrade -y"
    echo_run "apt autoremove -y"
    echo_run "sleep 5"
    echo_run "reboot"
}

iptables_blacklist() {
    echo_run "iptables -A OUTPUT -d 141.101.0.0/16 -j DROP"
    echo_run "iptables -A OUTPUT -d 173.245.0.0/16 -j DROP"
    echo_run "apt install iptables-persistent -y"
    echo_run "invoke-rc.d netfilter-persistent save"
}

install_ssl() {
    echo_run "apt install certbot docker.io docker-compose -y"
    echo_run "certbot certonly --email $CERTBOT_EMAIL -d $DOMAIN -d $DOMAIN_CDN --standalone --agree-tos --redirect --noninteractive"
}

install_3x-ui() {
    echo_run "mkdir -p ~/docker/3x-ui/"
    echo_run "cd ~/docker/3x-ui/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/{fullchain.pem,privkey.pem} ."
    echo_run "cp $PROJECT_CONFIGS/3x-ui/docker-compose.yml ."
    echo_run "docker-compose up -d"
}

install_xui_legacy() {
    echo_run "mkdir -p ~/docker/xui/"
    echo_run "cd ~/docker/xui/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/{fullchain.pem,privkey.pem} ."
    echo_run "cp $PROJECT_CONFIGS/x-ui/docker-compose.yaml ."
    echo_run "docker-compose up -d"
}

config_web_panel() {
    echo_run "gcf $PROJECT_PATH/v2ray_inbounds/v2ray.md"
}

setup_arvan_cdn() {
    echo "Turn CDN On"
    echo "HTTPS Settings: Enable + Wait till certificate get released"
    echo "HTTPS Protocol: Automatic"
}

install_ocserv() {
    echo_run "useradd -r -s /bin/false ocserv"
    echo_run "mkdir -p ~/docker/"
    echo_run "cp -rf  $PROJECT_CONFIGS/ocserv ~/docker/"
    echo_run "cd ~/docker/ocserv/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/{fullchain.pem,privkey.pem} ."
    echo_run "docker-compose up -d"
    echo "URL: $DOMAIN:8443"
}


install_ocserv_build() {
    echo_run "apt install build-essential pkg-config nettle-dev gnutls-bin libgnutls28-dev libprotobuf-c1 libev-dev libreadline-dev -y"
    echo_run "apt autoremove -y"
    echo_run "apt remove libpam-cap -y"
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
    echo_run "cp $PROJECT_CONFIGS/ocserv.conf /etc/ocserv/ocserv.conf"
    echo_run "echo \"server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem\" >> /etc/ocserv/ocserv.conf"
    echo_run "echo \"server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem\" >> /etc/ocserv/ocserv.conf"
    echo_run "cp $PROJECT_CONFIGS/ocserv.service /lib/systemd/system/ocserv.service"
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
    echo_run "invoke-rc.d netfilter-persistent save"
}

install_webmin() {
    echo_run "sh <(curl -s https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh)"
    echo_run "apt install webmin -y"
    echo "Panel: https://$DOMAIN:10000"
    echo "Login to Webmin panel as root"
    echo "Go to [Webmin → Webmin Configuration → SSL Encryption]"
    echo "In SSL Settings tab:"
    echo "Set [Private key file] to /etc/letsencrypt/live/$DOMAIN/privkey.pem"
    echo "Set [Certificate file] to Separate file and set to /etc/letsencrypt/live/$DOMAIN/cert.pem"
}

install_usermin() {
    echo "Go to webmin panel"
    echo "From Un-used Modules select Usermin"
    echo "click install and wait to install"
    echo "Press enter to continue"
    echo_run "read"
    echo_run "apt install usermin -y"
    echo "Go to webmin panel"
    echo "Login to Webmin panel as root"
    echo "Go to [Webmin → Usermin Configuration → SSL Encryption]"
    echo "In SSL Settings tab click on Copy Certificate From Webmin"
    echo "Usermin Panel: https://$DOMAIN:20000"
}

install_nginx() {
    echo_run "apt install nginx python3-certbot-nginx -y"
    echo_run "certbot --nginx -d $DOMAIN --noninteractive"
    echo_run "systemctl restart nginx"
}

install_nginx_xui() {
    echo_run "gcf $PROJECT_CONFIGS/x-ui/nginx > /etc/nginx/sites-available/x-ui.conf"
    echo_run "ln -s /etc/nginx/sites-available/x-ui.conf /etc/nginx/sites-enabled/"
    echo_run "certbot --nginx -d $DOMAIN -d $DOMAIN_CDN --noninteractive"
}

install_nginx_webmin() {
    echo_run "gcf $PROJECT_CONFIGS/webmin/webmin.conf > /etc/nginx/sites-available/webmin.conf"
    echo_run "ln -s /etc/nginx/sites-available/webmin.conf /etc/nginx/sites-enabled/"
    echo_run "certbot --nginx -d $DOMAIN -d webmin.$DOMAIN --noninteractive"
}

install_nginx_usermin() {
    echo_run "gcf $PROJECT_CONFIGS/webmin/usermin.conf > /etc/nginx/sites-available/usermin.conf"
    echo_run "ln -s /etc/nginx/sites-available/webmin.conf /etc/nginx/sites-enabled/"
    echo_run "certbot --nginx -d $DOMAIN -d user.$DOMAIN --noninteractive"
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
    install_3x-ui
    install_xui_legacy
    config_web_panel
    setup_arvan_cdn
    install_ocserv
    install_ocserv_build
    setup_ocserv_iptables
    install_webmin
    install_usermin
    install_nginx
    install_nginx_xui
    install_nginx_webmin
    install_nginx_usermin
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
