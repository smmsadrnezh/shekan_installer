## Login
Panel: http://$PUBLIC_IP:54321  
UN: admin  
PW: admin  
## Setup Panel Settings
#### Panel Setting -> Panel Settings:
Change port to $XUI_PORT  
Panel certificate public key file path: /root/cert/cert.crt  
Panel certificate key file path: /root/cert/private.key  
Time zone: Asia/Tehran  
#### Panel Setting -> Security Settings  
Current Username: admin  
Current Password: admin  
New Username: admin  
New Password: $NEW_PASSWORD  
#### Save and Restart  
Open panel at https://$DOMAIN:$XUI_PORT  

### Vless + TCP
enable: On  
remark: $REMARK_PREFIX-vl-c  
protocol: vless  
port: $XUI_VLC_PORT  
transmission: tcp  

### Vmess + TCP
enable: On
remark: $REMARK_PREFIX-vm-c  
protocol: vmess  
port: $XUI_VMC_PORT  
transmission: tcp  

### Vless + TCP + TLS
enable: On  
remark: $REMARK_PREFIX-vl-ct  
protocol: vless  
port: $XUI_VLCT_PORT  
transmission: tcp  
TLS: On  
public key file path: /root/cert/cert.crt  
key file path: /root/cert/private.key  

### Vmess + TCP + TLS
enable: On  
remark: $REMARK_PREFIX-vm-ct  
protocol: vmess  
port: $XUI_VMCT_PORT  
transmission: tcp  
TLS: On  
public key file path: /root/cert/cert.crt  
key file path: /root/cert/private.key  

### Vless + WS + TLS
enable: On  
remark: $REMARK_PREFIX-vl-wt  
protocol: vless  
port: $XUI_VLWT_PORT  
transmission: ws  
TLS: On  
public key file path: /root/cert/cert.crt  
key file path: /root/cert/private.key  

### Vless + gRPC
enable: On  
remark: $REMARK_PREFIX-vl-g  
protocol: vless  
port: $XUI_VLG_PORT
transmission: gRPC

### Vmess + WS + TLS
enable: On  
remark: s-vm-wt  
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
