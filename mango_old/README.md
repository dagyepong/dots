# mango-config
my mango config

![image](https://github.com/user-attachments/assets/7b0f9d38-f919-43a5-ba1d-7bb21a07eea8)

![image](https://github.com/user-attachments/assets/39238f7f-9e0b-4c9e-981e-0eddd5cb0d0b)


# dependence
```bash
yay -S rofi foot xdg-desktop-portal-wlr swaybg waybar wl-clip-persist cliphist wl-clipboard wlsunset xfce-polkit swaync pamixer wlr-dpms sway-audio-idle-inhibit-git swayidle dimland-git brightnessctl swayosd wlr-randr grim slurp satty swaylock-effects-git wlogout sox
```

# Usage
```bash
git clone https://github.com/Dreammango/mango-config.git ~/.config/mango
```
## Some Common Default Keybindings

- alt+return: open foot terminal
- alt+space: open rofi launcher
- alt+q: kill client
- alt+left/right/up/down: focus direction
- super+m: quit mango


### **Using Gsettings for themes:**

# Set Gruvbox Material theme
gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Material-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set org.gnome.desktop.interface font-name "Noto Sans 10"

# Enable dark mode
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'