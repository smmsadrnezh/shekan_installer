FROM ubuntu:23.04

RUN apt update
RUN apt install -y entr wget
WORKDIR /root/
RUN wget -O tuic https://github.com/EAimTY/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-linux-gnu && chmod 755 tuic
COPY start.sh .
RUN chmod +x start.sh
ENTRYPOINT /root/start.sh
