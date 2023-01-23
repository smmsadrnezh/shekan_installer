#!/bin/bash

CERTBOT_EMAIL="email"
DOMAIN1="ray.example.com"
DOMAIN2="rayc.example.com"
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
    certbot certonly --email $CERTBOT_EMAIL -d $DOMAIN1 -d $DOMAIN2 --standalone --agree-tos --redirect --noninteractive
    ln -s /etc/letsencrypt/live/$DOMAIN1/fullchain.pem ~/docker/xui/
    ln -s /etc/letsencrypt/live/$DOMAIN1/privkey.pem ~/docker/xui/
}

install_xui() {
    cp $PROJECT_PATH/docker-compose.yaml ~/docker/xui/
    cd ~/docker/xui/
    docker-compose up -d
}

install_namizun() {
    apt install proxychains -y
    ssh -NfD 9050 $SSHPROXY
    sudo curl https://raw.githubusercontent.com/malkemit/namizun/master/else/setup.sh | sudo proxychains bash
}

install_ocserv() {
    apt install build-essential pkg-config nettle-dev gnutls-bin libgnutls28-dev libprotobuf-c1 libev-dev libreadline-dev -y
    apt autoremove -y
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    mkdir /etc/ocserv
    certtool --generate-dh-params --outfile /etc/ocserv/dh.pem
    wget https://www.infradead.org/ocserv/download/ocserv-1.1.6.tar.xz
    tar xvf ocserv-1.1.6.tar.xz
    cd ocserv-1.1.6/
    ./configure --sysconfdir=/etc/ && make && make install
    ocpasswd -c /etc/ocserv/ocpasswd $OCSERVUSER
    cp $PROJECT_PATH/ocserv.conf /etc/ocserv/ocserv.conf
    echo "server-cert = /etc/letsencrypt/live/$DOMAIN1/fullchain.pem" >> /etc/ocserv/ocserv.conf
    echo "server-key = /etc/letsencrypt/live/$DOMAIN2/privkey.pem" >> /etc/ocserv/ocserv.conf
    sudo systemctl start ocserv
    sudo systemctl enable ocserv
}

ACTIONS=(
    server_initial_setup
    install_ssl
    install_xui
    install_ocserv
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
