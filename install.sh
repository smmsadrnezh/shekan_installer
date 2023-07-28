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
    echo_run "apt install -y apg"
    echo_run "apt full-upgrade -y"
    echo_run "apt autoremove -y"
    echo_run "sleep 5"
    echo_run "reboot"
}

server_upgrade_release() {
    echo_run "sed -i -e 's/Prompt=lts/Prompt=nomral/g' /etc/update-manager/release-upgrades"
    echo_run "do-release-upgrade"
}

install_ssl() {
    echo_run "apt install certbot docker.io docker-compose -y"
    echo_run "certbot certonly --email $CERTBOT_EMAIL -d $DOMAIN -d $DOMAIN_CDN --standalone --agree-tos --redirect --noninteractive"
}

install_3x-ui() {
    echo_run "mkdir -p ~/docker/3x-ui/"
    echo_run "cd ~/docker/3x-ui/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/{fullchain.pem,privkey.pem} ."
    echo_run "cp $PROJECT_PATH/configs/3x-ui/docker-compose.yml ."
    echo_run "docker-compose up -d"
}

install_xui_legacy() {
    echo_run "mkdir -p ~/docker/xui/"
    echo_run "cd ~/docker/xui/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/{fullchain.pem,privkey.pem} ."
    echo_run "cp $PROJECT_PATH/configs/x-ui/docker-compose.yaml ."
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
    echo_run "mkdir -p ~/docker/"
    echo_run "cp -rf ./configs/ocserv ~/docker/"
    echo_run "cd ~/docker/ocserv/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/{fullchain.pem,privkey.pem} ."
    echo_run "docker-compose up -d"
    echo "URL: $DOMAIN:8443"
}


install_ocserv_build() {
    echo ''
}


setup_ocserv_iptables() {
    echo_run "iptables -A FORWARD -s 172.16.0.0/255.240.0.0 -j ACCEPT"
    echo_run "iptables -A FORWARD -s 10.0.0.0/255.0.0.0 -j ACCEPT"
    echo_run "iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT"
    echo_run "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
    echo_run "iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS  --clamp-mss-to-pmtu"
    echo_run "apt install iptables-persistent -y"
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

install_nginx() {
    echo_run "apt install nginx python3-certbot-nginx -y"
    echo_run "certbot --nginx -d $DOMAIN --noninteractive"
    echo_run "systemctl restart nginx"
}

install_nginx_xui() {
    echo_run "gcf $PROJECT_PATH/x-ui.conf > /etc/nginx/sites-available/x-ui.conf"
    echo_run "ln -s /etc/nginx/sites-available/x-ui.conf /etc/nginx/sites-enabled/"
    echo_run "certbot --nginx -d $DOMAIN -d $DOMAIN_CDN --noninteractive"
    echo_run "nginx -t"
    echo_run "systemctl restart nginx"
}

install_nginx_webmin() {
    echo_run "gcf $PROJECT_PATH/webmin.conf > /etc/nginx/sites-available/webmin.conf"
    echo_run "ln -s /etc/nginx/sites-available/webmin.conf /etc/nginx/sites-enabled/"
    echo_run "certbot --nginx -d $DOMAIN -d webmin.$DOMAIN_CDN --noninteractive"
    echo_run "nginx -t"
    echo_run "systemctl restart nginx"
}

install_namizun() {
    echo_run "apt install proxychains -y"
    echo_run "ssh -NfD 9050 $SSHPROXY"
    echo_run "sudo curl https://raw.githubusercontent.com/malkemit/namizun/master/else/setup.sh | sudo proxychains bash"
}

ACTIONS=(
    setup_dns
    server_initial_setup
    server_upgrade_release
    install_ssl
    install_3x-ui
    install_xui_legacy
    config_web_panel
    setup_arvan_cdn
    install_ocserv
    install_ocserv_build
    setup_ocserv_iptables
    install_webmin
    install_nginx
    install_nginx_xui
    install_nginx_webmin
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
