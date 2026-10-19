# hypr config for the sekaipop shell

Lua config for Hyprland 0.55+, built on end-4's dots-hyprland layout and rewritten around
`qs -c sekaipop`. **Not run on a live Hyprland** (none here): the Lua was checked for balanced
brackets / blocks / strings and every `ipc call` was checked against the shell's `IpcHandler`s,
but nothing has been loaded by Hyprland itself.

## Install

    cd ~/.config
    mv hypr hypr.bak
    unzip ~/Downloads/hypr_sekaipop.zip
    cp hypr.bak/sekaipop_overrides.lua hypr.bak/monitors.lua hypr/   # your live copies, not the snapshot in the zip
    cp hypr.bak/custom/*.lua hypr/custom/                           # only if you added things there
    hyprctl reload        # then log out and back in once: the startup list changed

`hyprctl configerrors` shows anything Hyprland refused to load.

## What was wrong with the old config

It was Illogical Impulse's, so it talked to a shell that is not running:

- every `quickshell:...` global shortcut except `searchToggleRelease` does not exist in sekaipop;
- every `qs ... ipc call TEST_ALIVE || <fallback>` pair always ran the fallback (sekaipop has no
  `TEST_ALIVE`), so SUPER+V opened fuzzel, SUPER+SHIFT+S ran hyprshot, and so on;
- the layer rules matched `quickshell:*` namespaces; sekaipop's are `sekaipop-*`;
- startup ran things the shell does itself (clipboard watcher, cursor, video wallpaper) or that
  call II-only IPC (`cliphistService`);
- `hyprland/shellOverrides/main.lua` was II's generated file, loaded before sekaipop's.

## What it is now

| File | |
|---|---|
| `hyprland.lua` | load order; `sekaipop_overrides.lua` stays last |
| `hyprland/variables.lua` | `QS_IPC`, terminal (also exported as `$TERMINAL`), apps |
| `hyprland/execs.lua` | session env, keyring, cursor fallback, the shell, hypridle, easyeffects |
| `hyprland/general.lua` | Hyprland options and animations (gaps/border/colours are the shell's to change) |
| `hyprland/rules.lua` | window rules, plus one layer rule: no compositor animation on `^sekaipop-` |
| `hyprland/keybinds.lua` | see below |
| `hypridle.conf` | unchanged behaviour: lock via the shell, screen off 10 min, sleep 15 min |

Keybinds (II muscle memory kept where the shell has the feature): Super tap Apps, SUPER+A Apps,
SUPER+N Quick Panel, SUPER+Tab Overview, SUPER+I Settings, SUPER+/ Cheatsheet, SUPER+K keyboard,
SUPER+M Equalizer, SUPER+G Game Mode, SUPER+SHIFT+E Edit Desktop, SUPER+SHIFT+F Focus Mode,
CTRL+SUPER+T Wallpapers, CTRL+SUPER+ALT+T random wallpaper, CTRL+SUPER+SHIFT+D dark mode,
CTRL+SUPER+SHIFT+T theme picker, CTRL+SUPER+R restart shell, SUPER+L lock,
SUPER+SHIFT+S / X / A / R region snip / OCR / Lens / record, volume and brightness keys through
the shell's OSD (wpctl / brightnessctl if the shell is down). Window and workspace binds are II's.

Cheatsheet groups: Hyprland's Lua config reports every bind as `__lua`, so the shell's cheatsheet
(SUPER+/) groups binds by their description, written `Group: sentence` (Shell, Utilities, Windows,
Workspaces, Session, Screen, Media, Apps). `Group (more): sentence` keeps a bind out of the short list
(alternate keys, test keys); the cheatsheet's "+N more" chip shows them. Use the same form for your own
binds in `custom/keybinds.lua`.

## Behaviour changes to know about

- Workspace keys are plain `1..10`. II's "workspace groups" (`SUPER+3` on workspace 12 going to 13)
  are gone: the shell's bar numbers workspaces 1..N.
- Option values that II's generated override file used to force are now the defaults here:
  rounding 22, blur size 1, touchpad natural scroll off, click-finger off, focus-on-activate off.
- Removed (nothing in sekaipop uses them): fuzzel / wlogout / hyprshot / geoclue / ollama scripts,
  hyprlock.conf and its colours (the shell has its own lockscreen), `*.new` leftovers, the empty
  `workspaces.conf`, the hyprlang `monitors.conf`, II's `colors.lua`, `shellOverrides`, `custom/scripts`.
- Not bound (no matching IPC): II's sidebar / OSK-overlay / bar toggle / media-controls / panel-family
  / session menu, fullscreen recording, AI summary. Commented examples for the other IPC targets
  are at the end of `keybinds.lua`.

## Needs

`playerctl` for the media keys (the shell reads players itself but has no IPC to drive them).
Everything else on the binds is already on the shell's dependency list (grim, slurp, wl-clipboard,
wtype, hyprpicker, jq, libnotify, brightnessctl, wireplumber).

## To test

1. `hyprctl reload`, then `hyprctl configerrors`.
2. Super tap, SUPER+N, SUPER+Tab, SUPER+/ (the cheatsheet should list them), SUPER+I.
3. Volume / brightness keys show the shell's OSD.
4. SUPER+SHIFT+S: picker opens with no zoom; SUPER+L locks; SUPER+ALT+F11 / F12 send test notifications.
5. SUPER+V and SUPER+. open Apps with the Clip / Emoji card already up (`ipc call launcherphone toggleMode clip|emoji`),
   and pressing the same key again puts the phone away. No wtype and no timing involved any more.
6. Open the quick panel and the phone a few times: no flash or lifted edge (that is what the layer rule is for).
