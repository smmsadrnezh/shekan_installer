#!/bin/bash

if [ ! -f ".env" ]; then
    echo ".env file does not exist."
    exit
fi

if ! grep -q "NEW_PASSWORD=" .env; then
    echo "export NEW_PASSWORD=\"$(
        tr -dc A-Za-z0-9 </dev/urandom | head -c 13
        echo ''
    )\"" >>.env
fi

source .env

# Varibales
export PUBLIC_IP=$(curl -s ifconfig.me)
export REMARK_PREFIX=$(echo $DOMAIN | cut -d '.' -f1)

# SCRIPT SETUP

export PROJECT_PATH="$(dirname $(realpath "$0"))"
cd "$PROJECT_PATH" || exit

export PROJECT_CONFIGS="$PROJECT_PATH/configs"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# UTILITY FUNCTIONS

export TERMINAL_COLUMNS="$(stty -a 2>/dev/null | grep -Po '(?<=columns )\d+' || echo 0)"

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
    echo -e "Add the following DNS record to CloudFlare:"
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

block_ipv6() {
    echo_run "gcf $PROJECT_CONFIGS/sysctl/ipv6-block.conf > /etc/sysctl.d/10-ipv6-block.conf"
    echo_run "sysctl -p"
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

install_tuic() {
    echo_run "mkdir -p ~/docker/tuic/"
    echo_run "cd ~/docker/tuic/"
    echo_run "ln -s /etc/letsencrypt/live/$DOMAIN/{fullchain.pem,privkey.pem} ."
    export UUID=$(uuidgen)
    export PASSWORD=$(
        tr -dc A-Za-z0-9 </dev/urandom | head -c 13
        echo ''
    )
    echo_run "cp $PROJECT_CONFIGS/tuic/* ."
    echo_run "gcf $PROJECT_CONFIGS/tuic/config.json > config.json"
    echo_run "docker-compose up -d --force-recreate --build"
    echo "Use this config in NekoBox:"
    echo "tuic://$UUID:$PASSWORD@$DOMAIN:8585/?congestion_control=bbr&udp_relay_mode=native&alpn=h3%2Cspdy%2F3.1&allow_insecure=1#$REMARK_PREFIX-tuic"
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
    echo_run "echo \"auth = \"plain[/etc/ocserv/ocpasswd]\"\" >> /etc/ocserv/ocserv.conf"
    echo_run "cp $PROJECT_CONFIGS/ocserv/ocserv.service /lib/systemd/system/ocserv.service"
    echo_run "systemctl daemon-reload"
    echo_run "systemctl start ocserv"
    echo_run "systemctl enable ocserv"
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

backup_pam_users() {
    echo_run "mkdir /root/move/"
    echo_run "export UGIDLIMIT=500"
    echo_run "awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd > /root/move/passwd.mig"
    echo_run "awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group > /root/move/group.mig"
    echo_run "awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | tee - |egrep -f - /etc/shadow > /root/move/shadow.mig"
    echo_run "cp /etc/gshadow /root/move/gshadow.mig"
    echo_run "scp -r /root/move/* root@NEW_SERVER_IP_ADDRESS:/root/"
}

restore_pam_users() {
    echo_run "mkdir /root/newsusers.bak"
    echo_run "cp /etc/passwd /etc/shadow /etc/group /etc/gshadow /root/newsusers.bak"
    echo_run "cat /root/passwd.mig >> /etc/passwd"
    echo_run "cat /root/group.mig >> /etc/group"
    echo_run "cat /root/shadow.mig >> /etc/shadow"
    echo_run "cp /root/gshadow.mig /etc/gshadow"
    echo_run "rm /root/{*.mig,newsusers.bak}"
    echo_run "reboot"
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
    echo "Go to webmin panel: https://$DOMAIN:10000"
    echo "From Un-used Modules select Usermin"
    echo "click install and wait to install"
    echo "Press enter to continue"
    echo_run "read"
    echo_run "apt install usermin -y"
    echo "Go to webmin panel"
    echo "Login to Webmin panel as root"
    echo "Go to [Webmin → Usermin Configuration]"
    echo 'Click on "Start Usermin"'
    echo "Go to [Webmin → Usermin Configuration → SSL Encryption]"
    echo "In SSL Settings:"
    echo "Set [Private key file] to /etc/letsencrypt/live/$DOMAIN/privkey.pem"
    echo "Set [Certificate file] to Separate file and set to /etc/letsencrypt/live/$DOMAIN/cert.pem"
    echo "Go to [Webmin → Usermin Configuration → Module Restrictions]"
    echo 'Select "Add a new user or group restriction"'
    echo 'Click on "Members of group" and type "users"'
    echo 'Select Change Password'
    echo 'Click on "Create"'
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
    echo -e "Add the following DNS record to CloudFlare:"
    echo -e "\tType: CNAME"
    echo -e "\tFrom: webmin.$DOMAIN"
    echo -e "\tValue: $DOMAIN"
    echo -e "\tProtocol: Default"
    echo "Press enter to continue"
    echo_run "read"
    echo_run "echo 'referers=webmin.$DOMAIN' >> /etc/webmin/config"
    echo_run "echo 'webprefixnoredir=1' >> /etc/webmin/config"
    echo_run "sed -i 's/ssl=.*/ssl=0/' /etc/webmin/miniserv.conf"
    echo_run "sed -i 's/redirect_ssl=.*/redirect_ssl=1/' /etc/webmin/miniserv.conf"
    echo_run "echo 'redirect_host=webmin.$DOMAIN' >> /etc/webmin/miniserv.conf"
    echo_run "systemctl restart webmin.service"
    echo_run "gcf $PROJECT_CONFIGS/webmin/webmin.conf > /etc/nginx/sites-available/webmin.conf"
    echo_run "ln -s /etc/nginx/sites-available/webmin.conf /etc/nginx/sites-enabled/"
    echo_run "certbot --nginx -d $DOMAIN -d webmin.$DOMAIN --noninteractive --expand"
    echo "URL: https://webmin.$DOMAIN"
}

install_nginx_usermin() {
    echo -e "Add the following DNS record to CloudFlare:"
    echo -e "\tType: CNAME"
    echo -e "\tFrom: user.$DOMAIN"
    echo -e "\tValue: $DOMAIN"
    echo -e "\tProtocol: Default"
    echo "Press enter to continue"
    echo_run "read"
    echo_run "echo 'referers=user.$DOMAIN' >> /etc/usermin/config"
    echo_run "echo 'webprefixnoredir=1' >> /etc/usermin/config"
    echo_run "sed -i 's/ssl=.*/ssl=0/' /etc/usermin/miniserv.conf"
    echo_run "sed -i 's/redirect_ssl=.*/redirect_ssl=1/' /etc/usermin/miniserv.conf"
    echo_run "echo 'redirect_host=user.$DOMAIN' >> /etc/usermin/miniserv.conf"
    echo_run "systemctl restart usermin.service"
    echo_run "gcf $PROJECT_CONFIGS/usermin/usermin.conf > /etc/nginx/sites-available/usermin.conf"
    echo_run "ln -s /etc/nginx/sites-available/usermin.conf /etc/nginx/sites-enabled/"
    echo_run "certbot --nginx -d $DOMAIN -d user.$DOMAIN --noninteractive --expand"
    echo "URL: https://user.$DOMAIN"
}

install_namizun() {
    echo_run "apt install proxychains -y"
    echo_run "ssh -NfD 9050 $SSHPROXY"
    echo_run "sudo curl https://raw.githubusercontent.com/malkemit/namizun/master/else/setup.sh | sudo proxychains bash"
}

setup_fail2ban() {
    echo_run "apt install fail2ban -y"
    echo_run "cp $PROJECT_CONFIGS/jail/jail.local /etc/fail2ban/"
    echo_run "systemctl restart fail2ban"
    echo_run "sleep 1"
    echo_run "fail2ban-client status"
}

setup_firewall() {
    echo_run "cp $PROJECT_CONFIGS/ufw/ufw.conf /etc/ufw/applications.d/ufw.conf"
    echo_run "ufw allow web"
    echo_run "ufw allow ocserv"
    echo_run "ufw allow v2ray"
    echo_run "ufw allow ssh"
    echo_run "ufw --force enable"
    echo_run "ufw default deny incoming"
    echo_run "ufw status verbose"
}

build_mtproxy() {
    echo_run "git clone https://github.com/TelegramMessenger/MTProxy /opt/MTProxy"
    echo_run "cd /opt/MTProxy"
    echo_run "make && cd objs/bin"
}

run_mtproxy() {
    echo_run "curl -s https://core.telegram.org/getProxySecret -o proxy-secret"
    echo_run "curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf"
    echo_run "head -c 16 /dev/urandom | xxd -ps"
    echo " /opt/MTProxy/objs/bin/mtproto-proxy -u nobody -p 8888 -H 9000 -S YOUR_SECRET --aes-pwd /opt/MTProxy/objs/bin/proxy-secret /opt/MTProxy/objs/bin/proxy-multi.conf -M 2"
    echo_run "cp $PROJECT_CONFIGS/mtproxy/MTProxy.service /etc/systemd/system/MTProxy.service"
    echo_run "systemctl daemon-reload"
    echo_run "systemctl start MTProxy.service"
    echo_run "systemctl enable MTProxy.service"
}

ACTIONS=(
    setup_dns
    server_initial_setup
    iptables_blacklist
    install_ssl
    install_tuic
    install_3x-ui
    config_web_panel
    install_ocserv
    install_webmin
    install_usermin
    install_nginx
    install_nginx_webmin
    install_nginx_usermin

    # Old Methods
    install_xui_legacy
    setup_arvan_cdn
    install_ocserv_build
    setup_ocserv_iptables
    install_nginx_xui
    install_namizun
    setup_fail2ban
    setup_firewall
    build_mtproxy
    run_mtproxy
    backup_pam_users
    restore_pam_users
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
