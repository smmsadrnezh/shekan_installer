#!/bin/bash

ls ~/etc/{passwd,shadow} | entr -nr bash -c "cp ~/etc/{passwd,shadow} /etc/ && echo 'users updated'" &
iptables -A INPUT -p tcp --dport 443 -j ACCEPT &&
    iptables -A INPUT -p udp --dport 443 -j ACCEPT &&
    iptables -t nat -A POSTROUTING -j MASQUERADE
ocserv -c /etc/ocserv/ocserv.conf -f
