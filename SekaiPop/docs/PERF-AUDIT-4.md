# Performance audit 4: activation registry, on-demand screens, low-end mode

Status: **static changes only.** Nothing here was run on a live Quickshell/Hyprland (the build
environment had no `qs`, `qmllint`, `hyprctl` or GPU). No before/after numbers exist; none are claimed.
Measure with `tests/perf-test/perf-baseline.sh` and `smaps_rollup` before keeping this.

## A. Audit findings (priority order)

1. **Desktop widget windows are full-screen by default.** `EditMode.compactWindows` defaults to
   `false`, so every shown widget (clock, to-do, user card, weather, calendar, palette, image,
   visualizer) is a full-screen transparent layer. Only the lyrics widget is compact. This
   contradicts the "card-sized at rest" note in the DEVLOG's pass-1 audit. The default was left off
   on purpose earlier because widgets jumped when Edit Desktop closed. Now reachable via Low-end mode.
2. **Bottom and right bars use a full-monitor window** (`growsFromOrigin` in `Bar.qml`); only top and
   left are compact. Not changed: needs a live test of the Edit Desktop jump.
3. **Sticky-notes layers are full-screen.** Not changed (already noted in pass 1).
4. **Timers and animations are clean.** Every repeating `Timer`, `FrameAnimation` and
   `loops: Animation.Infinite` is state-gated or started on demand.
5. **Eager trees still built at start:** Quick Panel/Settings phone, Edit Desktop shelf, desktop menu,
   notification popups, OSD, reload report, region picker, on-screen keyboard, welcome screen.
   The cheat sheet, Palette tool and workspace board were also eager; those three are fixed below.
6. **Duplicate MPRIS consumer:** `PaletteTool` owned its own `MediaSource` from shell start.

## B. Changes

| File | Problem | Change | Risk |
|---|---|---|---|
| `services/ComponentActivation.qml` (new) | no registry of on-demand screens | singleton of bool flags, all `false`, `setActive()`, instantiates nothing | low |
| `services/ActivationEntry.qml` (new) | open requests could race with build/teardown | one entry per screen: raises flag, delivers the request after build (`Qt.callLater`), lowers flag only when `open` and `closing` are false and nothing waits | `LazyLoader` build timing assumed synchronous; first open builds the tree |
| `modules/sekai/overview/OverviewEntry.qml` (new) | plugin/Edit Desktop rules lived inside the board | same `openOn`/`toggleOn`/`hide` rules outside the board; with the ScrollOverview plugin loaded the board is never built | plugin path untested |
| `shell.qml` | cheat sheet, Palette tool, board eagerly built | three `LazyLoader`s on registry flags; `ipc` handlers `cheatsheet`, `palette`, `overview` moved here; Quick Panel `coverCheat` reads the entry | IPC names unchanged |
| `CheatSheet.qml`, `PaletteTool.qml`, `Overview.qml` | handlers inside a lazy screen would vanish with it | handlers, `PaletteService.openRequested` hook and the Overview `EditMode` hook removed (now in `shell.qml` / `OverviewEntry`) | none found |
| `SettingsService.qml`, `FocusService.qml`, `EditMode.qml`, `SettingsPageDesktop.qml` | no single switch for the costly behaviours | `perf.lowEnd` (default off): counts as `focus.unload` and `focus.reduceEffects` on, and turns on compact widget windows; `ipc call desktopedit compactwindows` still overrides until reload; switch under Settings → Desktop → Low-end mode | widgets may jump when Edit Desktop closes (the reason it was off) |
| `tests/perf-test/activation_unit.js` (new), `tests/palette-test/palette_source_test.js` | | new test; palette test now finds its handler in `shell.qml` and keeps the "cannot apply" assertion | |

## C. Performance comparison

Not measured. Expected direction only (estimates, not results): less resident QML and one fewer
`MediaSource` at idle; fewer GPU-damaged pixels with Low-end mode on.

## D. Verification

Run: `activation_unit.js` (366k checks, 3,000 random open/toggle/close sequences) passes; full node
suite 60 pass / 6 fail, and the same 6 fail on the untouched original
(`chart_test`, `lyrics_source_test`, `power_press_test`, `popup_origin_test`,
`preset_images_unit`, `wheel_source_test`).

Not run (needs a live shell): startup, bar/dock surface sizes, `ipc call cheatsheet|palette|overview`
open/close, repeated open/close leak check, ScrollOverview plugin path, Edit Desktop with Low-end
mode, workspace/monitor changes, media, wallpapers, QML lint, memory/CPU/GPU comparison.

## E. Still open

Edit Desktop shelf, desktop menu, notification popups, on-screen keyboard (view-only trees); splitting
the Quick Panel into controller and view; bottom/right bar window size; sticky-notes layers.
