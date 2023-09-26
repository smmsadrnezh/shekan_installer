# Shekan Installer
Scripts to deploy v2ray and OcServ on Ubuntu

## Check IP
To check ping of your IP from multiple locations in Iran use this website: [link](https://www.host-tracker.com/en/ic/ping-test)

## Installation
Download the scripts:

```
git clone https://github.com/smmsadrnezh/shekan_installer.git
cd shekan_installer
```

Edit configuration:
```
cp .env.sample .env
nano .env
```

Run the installer:
```
bash install.sh
```

## NOTE
- Your VPS architecture must be Intel/AMD.
- Make sure to have IPV6 turned off.
