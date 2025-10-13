### **Install:**

```bash
paru -S betterlockscreen
```

#### **Set a wallpaper:**

```bash
betterlockscreen -u /path/to/your/wallpaper.jpg
```

#### **Lock with a specific effect:**
```bash
betterlockscreen -l blur
```
#### **Lock the screen automatically on inactivity (optional):**

```bash
paru -S xautolock
```

#### **Configure xautolock in autostart:**
Add the following line to your ~/.config/herbstluftwm/autostart file. This example will lock the screen after 10 minutes (600 seconds) of inactivity.
```bash
hc spawn xautolock -time 10 -locker 'betterlockscreen -l' &
```
### **Lock the screen on suspend (optional)**
```bash
sudo systemctl enable betterlockscreen@<your_username>.service
```

#### **Start the service to apply it immediately.**
```bash
sudo systemctl start betterlockscreen@<your_username>.service
```
