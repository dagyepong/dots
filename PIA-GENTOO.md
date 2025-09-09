### **Private Internet Access-Gentoo-INstall**

My OpenRC init script is below – this just goes in /etc/init.d/pia. I’m not expert on OpenRC, so it’s possible I’ve got something wrong; but this configuration seems to work for me.

```py

cd /etc/init.d/

sudo nano pia-daemon

sudo groupadd --system pia
sudo useradd --system --gid pia --home-dir /opt/piavpn --no-create-home pia



chown -R pia:pia /opt/piavpn


rc-update add net.lo boot


rc-service pia-daemon start   

```

### **Paste this script**

```bash

#!/sbin/openrc-run

name="pia-daemon"
description="Private Internet Access Daemon"

command="/opt/piavpn/bin/pia-daemon"
command_background=true
pidfile="/run/${name}.pid"
directory="/opt/piavpn"
user="pia"
group="pia"

# Do not 'need net' — it does not exist as a service
# Instead, want net (soft dependency) and depend on local filesystems
want net
depend() {
    after firewall
    after dns
    after logger
    need localmount
    need sysfs
    need devfs
}

start_pre() {
    # Ensure runtime directory exists
    if [ ! -d "/run/pia-daemon" ]; then
        mkdir -p /run/pia-daemon
        chown pia:pia /run/pia-daemon
    fi
    return 0
}   
```


sudo chmod +x pia-daemon

### **To make the daemon start at boot:**

```bash
 sudo rc-update add pia default
 ```
