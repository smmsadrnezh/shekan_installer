FROM ubuntu:23.04

RUN apt update
RUN apt install -y entr wget
RUN wget -O tuic-server https://github.com/EAimTY/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-linux-gnu && chmod 755 tuic-server
COPY config.json /root/
COPY start.sh /root/
RUN chmod +x /root/start.sh
ENTRYPOINT /root/start.sh
