# basedgoose.shell

Quickshell setup for Hyprland

## Preview

![screenshot](assets/screenshot.png?raw=true)

## Features

- Bar
- App launcher
- Bluetooth management
- Calendar
- Media player controls
- Notification center
- Power menu
- Volume controls
- Wallpaper selector (local + Wallhaven)
- Display manager

## Installation

1. Install dependencies:
   - `pamixer`
   - `wl-clipboard`
   - `awww`
   - `zenity` or `yad`
   - `wlr-randr`
   - `curl`
   - `imagemagick`
   - `fd`

2. Clone this repository to your Quickshell config directory:
   ```bash
   git clone https://github.com/obsqrbtz/basedgoose.shell.git ~/.config/quickshell/basedgoose.shell
   ```

3. Start Quickshell:
   ```bash
   qs -c basedgoose.shell
   ```

## IPC Usage

All popups and menus can be toggled via IPC commands. Use the following format:

```bash
qs -c basedgoose.shell ipc call <target> <action>
```

Available targets and actions:

- `wallpaper` - Wallpaper selector
- `calendar` - Calendar popup
- `launcher` - App launcher
- `power` - Power menu
- `volume` - Volume popup
- `cheatsheet` - IPC cheatsheet
- `shellmenu` - Shell menu
- `notificatios` - Notification center
- `display` - Display manager

Each target supports `toggle`, `open`, and `close` actions.

## Acknowledgments

- [noctalia-shell](https://github.com/noctalia-dev/noctalia-shell)
- [tripathiji1312/quickshell](https://github.com/tripathiji1312/quickshell)
