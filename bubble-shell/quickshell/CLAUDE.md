# Quickshell clock rice — project context

## System
- CachyOS, Hyprland 0.54.3, NVIDIA 4080
- Display: 3840×2400 (HiDPI)
- Terminal: kitty
- Dotfiles: bare repo at `~/.dotfiles`, `dots` alias, pushed to github.com/amarsbar/bubbles-dots

## Entry point & layout
- `shell.qml` — top-level `ShellRoot` loaded by `qs -c clock`
- Clock pill, settings popup, wifi popup, battery panel, notification module, notification center all live here
- Restart: `pkill -f "qs -c clock"; qs -c clock &`
- Logs: `tail -30 /run/user/1000/quickshell/by-id/$(ls -t /run/user/1000/quickshell/by-id/ | head -1)/log.qslog`

## Components
- `Pill.qml` — generic pill with SDF fragment shader (`pill.frag.qsb`). Parameters: `animationDuration`, `animateShader`, `shaderEnabled`, `restFill1/2`, `hoverFill1/2`, `glowEnabled`, `activeCornerRadius`
- `NotificationModule.qml` — two `PanelWindow`s (main at `WlrLayer.Top`, big at `WlrLayer.Overlay` for z-order). `currentToast` derived from `notifServer.trackedNotifications` (single source of truth). Auto-hide timers: Low 2.5s, Normal 5s, Critical 60s. Critical urgency morphs into a big sibling pill. Notification center (scrollable list) is inlined into the expanded pill.
- `SettingsContent.qml` — settings surface with nested panels (wifi / sound / bluetooth / power views). Wi-Fi password entry is inline.
- `NetworkService.qml` — Wi-Fi management via `nmcli` subprocess
- `BatteryPanel.qml` (unused, preserved as a future opt-in), `*Icon.qml`, `*.svg` — supporting UI

## Shaders
- Sources: `pill.frag`, `album_blur.frag`, `album_glow.frag`
- Compiled: `*.qsb` (generated, excluded from git via `~/.dotfiles/info/exclude`)
- Rebuild: `qsb --qt6 -o pill.frag.qsb pill.frag` (same for others)

## Hyprland config (`~/.config/hypr/`)
- Split across `hyprland.conf`, `env.conf`, `keybinds.conf`, `rules.conf`, `autostart.conf`
- Blur: `size=7 passes=3 noise=0.01 contrast=0.95 brightness=1.0 vibrancy=0.25 ignore_opacity=true`
- Layer rules (modern syntax): `layerrule = blur on, match:namespace .*quickshell.*` and `layerrule = ignore_alpha 0.03, match:namespace .*quickshell.*`
- Always verify after edits: `Hyprland --verify-config -c ~/.config/hypr/hyprland.conf 2>&1 | tail -20`

## Design references
- Figma: notification states 276:16310 (outer pill w/ bell + toast sub-pills), 276:16337/16340 and 304:705/693 (four compact states), 303:670 + 295:17681/17682 (critical spec)

## Conventions & gotchas
- Use `TextMetrics.advanceWidth` for text sizing to break `implicitWidth ↔ anchors` feedback loops; don't anchor text.right when also animating its container width
- Animate structural properties (position/size/clip), not opacity, for state transitions — opacity fades look bad on this rice
- Big pill corner radius must be locked via `activeCornerRadius: height/2` or you get a hard-corner flash during 0→54 height morph
- `PanelWindow` z-order: `WlrLayer.Overlay > WlrLayer.Top`. Don't put sibling panels on the same layer and expect a fixed stack order.
- For docs: prefer context7 + `--verify-config` over stale web results; Hyprland layer-rule syntax has shifted between versions
