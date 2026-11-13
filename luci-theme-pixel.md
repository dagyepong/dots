if this command fails:

```bash
wget https://github.com/Trendorin/luci-theme-pixel/releases/latest/download/luci-theme-pixel.apk

```
```

download the file and move to /downloads/

```bash
 scp -O ~/Downloads/luci-theme-pixel.apk root@192.168.1.1:/tmp/
 ```
Install the Package:

```bash
cd /tmp
apk add --allow-untrusted luci-theme-pixel.apk
```