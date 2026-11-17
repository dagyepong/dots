Gentoo OpenRC + niri + tuigreet + Yami setup notes

The key fix was adding ~/.local/bin to the environment before niri starts. Your tuigreet already runs /usr/local/bin/start-desktop, so that’s the right place to set it.
1. Set PATH in the desktop startup script

```bash
vim /usr/local/bin/start-desktop:
```

```bash
#!/bin/sh
# Written by gentooinstall: the login screen runs this after a login.
export PATH="/home/nana/.local/bin:$PATH"
dbus-run-session niri --session
```


 Configure the file chooser portal

```bash
vim ~/.config/xdg-desktop-portal/portals.conf:
```

```bash
[preferred]
org.freedesktop.impl.portal.FileChooser=yami;gtk;
```

 Make the Rofi file-manager launcher use the full path

In ~/.local/share/applications/yami-files.desktop, use the full path in each Exec= entry:

```bash
[Desktop Entry]
Type=Application
Name=Files
Name[pt_BR]=Arquivos
Name[ru]=Файлы
GenericName=File Manager
GenericName[pt_BR]=Gerenciador de arquivos
GenericName[ru]=Файловый менеджер
Comment=Pixel-art file manager of the yami shell
Comment[pt_BR]=Gerenciador de arquivos em pixel art do yami
Exec=/home/nana/.local/bin/yami-files %U
Icon=yami-files
Terminal=false
MimeType=inode/directory;
Categories=System;FileTools;FileManager;Utility;
Keywords=folder;files;explorer;dolphin;
StartupWMClass=yami-files
Actions=new-window;trash;

[Desktop Action new-window]
Name=New window
Name[pt_BR]=Nova janela
Name[ru]=Файлы
Exec=/home/nana/.local/bin/yami-files

[Desktop Action trash]
Name=Trash
Name[pt_BR]=Lixeira
Name[ru]=Корзина
Exec=/home/nana/.local/bin/yami-files trash:///
```

