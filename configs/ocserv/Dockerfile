FROM ubuntu:23.04

RUN apt update
RUN apt install -y ocserv gnutls-bin iptables entr
RUN apt remove libpam-cap -y
COPY ocserv.conf /etc/ocserv/
COPY start.sh /etc/ocserv/
RUN chmod +x /etc/ocserv/start.sh
ENTRYPOINT /etc/ocserv/start.sh
