### **Private Internet Access-Gentoo-INstall**

My OpenRC init script is below – this just goes in /etc/init.d/pia. I’m not expert on OpenRC, so it’s possible I’ve got something wrong; but this configuration seems to work for me.

```py

cd /etc/init.d/

sudo nano pia
```

### **Paste this script**

```bash

#!/sbin/openrc-run

name="PIA daemon"
description="PIA daemon"
command=/opt/piavpn/bin/pia-daemon
command_background=yes
pidfile=/run/pia-daemon.pid

depend() 
  {
  need net
  }
```


sudo chmod +x pia

### **To make the daemon start at boot:**

```bash
 sudo rc-update add pia default
 ```