#!/bin/bash

CERTBOT_EMAIL="email"
DOMAIN1="ray.example.com"
DOMAIN2="rayc.example.com"
SSHPROXY="user@example.com"

# SCRIPT SETUP

export PROJECT_PATH="$(dirname $(dirname $(realpath "$0")))"
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
}

install_ssl() {
    apt install certbot docker.io docker-compose -y
    certbot certonly --email $CERTBOT_EMAIL -d $DOMAIN1 -d $DOMAIN2 --standalone --agree-tos --redirect --noninteractive
    ln -s /etc/letsencrypt/live/$DOMAIN1/fullchain.pem /root/docker/xui/
    ln -s /etc/letsencrypt/live/$DOMAIN1/privkey.pem /root/docker/xui/
}

install_xui() {
    mkdir -p ~/docker/xui/
    cp docker-compose.yaml ~/docker/xui/
    cd docker/xui/
    docker-compose up -d
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
