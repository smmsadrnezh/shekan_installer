## Login
Panel: http://$PUBLIC_IP:54321\
UN: admin\
PW: admin\
## Setup Panel Settings
Change xray Status to its latest version
Panel Setting -> Panel Configuration -> Change port to 7701
Panel Setting -> Panel Configuration -> Panel certificate public key file path: /root/cert/cert.crt
Panel Setting -> Panel Configuration -> Panel certificate key file path: /root/cert/private.key
Panel Setting -> User Setting -> Change password to $NEW_PASSWORD
Panel Setting -> Other Setting -> Change timezone to Asia/Tehran
Save and Restart
## Add Inbound Settings
Open panel at https://$DOMAIN:7701
### Vless + TCP
enable: On
remark: $REMARK_PREFIX-vl-c
protocol: vless
port: 2052
transmission: tcp
### Vmess + TCP
enable: On
remark: $REMARK_PREFIX-vm-c
protocol: vmess
port: 2082
transmission: tcp
### Vless + TCP + TLS
enable: On
remark: $REMARK_PREFIX-vl-ct
protocol: vless
port: 2053
transmission: tcp
TLS: On
public key file path: /root/cert/cert.crt
key file path: /root/cert/private.key
### Vmess + TCP + TLS
enable: On
remark: $REMARK_PREFIX-vm-ct
protocol: vmess
port: 2083
transmission: tcp
TLS: On
public key file path: /root/cert/cert.crt
key file path: /root/cert/private.key
### Vless + WS + TLS
enable: On
remark: $REMARK_PREFIX-vl-wt
protocol: vless
port: 2087
transmission: ws
TLS: On
public key file path: /root/cert/cert.crt
key file path: /root/cert/private.key
### Vmess + WS + TLS
enable: On
remark: $REMARK_PREFIX-vm-wt
protocol: vmess
port: 2096
transmission: ws
TLS: On
public key file path: /root/cert/cert.crt
key file path: /root/cert/private.key
## Add Client Profile
Add a user and add scan the QR Code for inbounds
For ws only:
Duplicate the profile
In the second profile replace $DOMAIN with $DOMAIN_CDN and port with 443
