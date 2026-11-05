
# Quickshell shell: commands and shortcuts

The shell starts with `qs`. Every function can be controlled from the terminal with:

    qs ipc call <target> <funzione>

## Comandi

| Command | What it does |
|---|---|
| `qs ipc call launcher toggle` | opens/closes the launcher |
| `qs ipc call wallpaper toggle` | wallpaper picker |
| `qs ipc call power toggle` | power menu (Lock, Logout, Suspend, Reboot, Shutdown) |
| `qs ipc call lock lock` | locks the screen |
| `qs ipc call lock test` | safe test: unlocks by itself after 12 seconds |
| `qs ipc call gamemode toggle` | Game Mode (turns off animations, blur, gaps) |
| `qs ipc call powersaver toggle` | Eco Mode (power-saving profile, brightness, Bluetooth) |
| `qs ipc call workspaces peek` | shows the workspaces in the pill and retracts |
| `qs ipc call workspaces toggle` | pins them in place / removes them |
| `qs ipc call system open` | resources pill (slides out from the left edge) |
| `qs ipc call system toggle` | keeps it out / retracts it |
| `qs ipc call capture toggle` | screenshot/video menu (or stops the recording) |
| `qs ipc call layout next` | switches keyboard layout |
| `qs ipc call layout test` | test toast for the layout |
| `qs ipc call calendar test` | test reminder |
| `qs ipc call audio dump` | writes the PipeWire nodes to the log (diagnostics) |

## Suggested shortcuts (add them by hand to your hyprland.lua)

    hl.bind("ALT + R", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
    hl.bind("ALT + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
    hl.bind("ALT + P", hl.dsp.exec_cmd("qs ipc call power toggle"))
    hl.bind("ALT + L", hl.dsp.exec_cmd("qs ipc call lock lock"))
    hl.bind("ALT + G", hl.dsp.exec_cmd("qs ipc call gamemode toggle"))
    hl.bind("ALT + E", hl.dsp.exec_cmd("qs ipc call powersaver toggle"))
    hl.bind("ALT + TAB", hl.dsp.exec_cmd("qs ipc call workspaces peek"))
    hl.bind("SUPER + TAB", hl.dsp.exec_cmd("qs ipc call workspaces toggle"))
    hl.bind("ALT + I", hl.dsp.exec_cmd("qs ipc call system toggle"))
    hl.bind("Print", hl.dsp.exec_cmd("qs ipc call capture toggle"))

If the variable for the Super key in your file is not called `mainMod`, use whatever name you have.

## niri

The same folder works on niri and on Hyprland: `services/Compositor.qml` detects the
compositor by itself (`NIRI_SOCKET` or `HYPRLAND_INSTANCE_SIGNATURE` variable) and translates workspaces,
monitors, keyboard layout, session logout and window screenshots.

- Shortcuts: `~/.config/niri/quickshell.kdl` (included by `config.kdl`), same keys as above.
- Game Mode and Eco Mode on niri write `~/.config/niri/quickshell-tweaks.kdl` (animations,
  blur, gaps) and niri reloads the configuration by itself. If the file does not exist they change nothing
  besides the notifications.
- Keyboard layout: in the niri config `layout "it,us,gb,fr,de"` inside `input > keyboard > xkb`.
- To blur the background of the full-screen menus (wallpaper) add to `config.kdl`:

      layer-rule {
          match namespace="shell-wallpaper"
          background-effect { blur true; }
      }

- The shell must start inside the niri session (`spawn-at-startup "quickshell"`), otherwise
  it does not see `NIRI_SOCKET`. With two shells running `qs ipc call` does not know which one to talk to.
For lockscreen safety: `hl.config({ misc = { allow_session_lock_restore = true } })`.
If `show` only prints the help, use `open` (resources) or `peek` (workspaces).

## Keys inside the menus

- Launcher: type to search, arrows to scroll, Tab switches section, Enter opens, Ctrl+F favorite (or right click), Esc closes.
  On a workspace with no windows just start typing to open it.
- Power / Capture / Wallpaper: left and right arrows, Enter confirms, Esc closes.
- Calendar: click a day for notes; Tab switches field, Enter saves, Ctrl+Enter saves from the description, Esc goes back.
- Control center: hover the circle on the right; the three dots at the top, the scroll wheel or Alt+1/2/3 switch between the three pages (main, tools, monitors).

## Where things live

    ~/.config/quickshell/
      shell.qml        starting point
      bar/             the island bar
      widgets/         pills and components (Clock, ControlIsland, MediaIsland...)
      pages/           control center pages
      services/        state and logic (network, audio, battery, clipboard, timers...)
                       Compositor.qml = everything that differs between Hyprland and niri
      lock/            lockscreen
      sysmon/          resources pill
      osd/             volume and brightness on the right edge
      scripts/         helper scripts
      _unused/         files no longer used (you can delete it)

Saved data: `~/.local/share/quickshell-calendar.json` (notes), `~/.cache/quickshell-*.json` (launcher, night light).

## Bar style

`qs ipc call style toggle` (niri: Alt+S) opens the picker at the center of the screen: arrows or 1-3, Enter to apply.
Styles: **Island** (centered pills) and **Classic** (full bar: launcher and clock on the left, workspaces in the center,
wifi · settings · bluetooth pill on the right). The choice is kept in ~/.local/state/quickshell/style.json.

**Dashboard** (third style): a single pill at the top that grows. Closed: workspaces · clock · wifi + battery.
Mouse over: clock and date, workspaces, music card and status. Click: the full dashboard (music, Wi-Fi / Bluetooth /
Night Mode / Game Mode tiles, brightness / volume / mic sliders, calendar, notifications, clipboard, CPU / RAM / battery bars).
Alt+1/2/3 (or the dots) switch between dashboard, tools and monitors. Esc, a click outside or moving the mouse away closes it.
