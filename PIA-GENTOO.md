#### **Private Internet Access-Gentoo-INstall**

My OpenRC init script is below – this just goes in /etc/init.d/pia. I’m not expert on OpenRC, so it’s possible I’ve got something wrong; but this configuration seems to work for me.

### **Create the OpenRC Init Script:**

```bash
sudo nano /etc/init.d/pia-daemon   
```


### **Paste the following content:**

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
    if [ ! -d "/run/pia-daemon" ]; then
        mkdir -p /run/pia-daemon
        chown pia:pia /run/pia-daemon
    fi
    return 0
}   
```

### **Make it executable:**

```bash
sudo chmod +x /etc/init.d/pia-daemon   
```

### **Ensure Required Dependencies Are Installed
PIA requires libgssapi_krb5.so.2. Install MIT Kerberos:**

```bash
sudo emerge --ask app-crypt/mit-krb5   
```

#### **5. Enable the Service at Boot**

```bash
sudo rc-update add pia-daemon default   
```
#### **6. Start the Daemon:**

```bash
sudo rc-service pia-daemon start   
```

```bash
sudo rc-service pia-daemon status   
```





