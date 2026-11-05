
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme

Scope {
    // Only one menu in the pill at a time: the theme selector closes the others, and they close it
    Connections {
        target: Appearance
        function onPickerOpenChanged() {
            if (Appearance.pickerOpen) {
                UiState.launcherOpen = false
                UiState.powerOpen = false
                UiState.wallpaperOpen = false
                UiState.captureOpen = false
                UiState.recMenuOpen = false
                Style.variantOpen = false
            }
        }
    }
    Connections {
        target: Style
        function onVariantOpenChanged() {
            if (Style.variantOpen) {
                Appearance.pickerOpen = false
                UiState.launcherOpen = false
                UiState.powerOpen = false
                UiState.wallpaperOpen = false
                UiState.captureOpen = false
                UiState.recMenuOpen = false
            }
        }
    }
    Connections {
        target: UiState
        function onLauncherOpenChanged() { if (UiState.launcherOpen) { Appearance.pickerOpen = false; Style.variantOpen = false } }
        function onPowerOpenChanged() { if (UiState.powerOpen) { Appearance.pickerOpen = false; Style.variantOpen = false } }
        function onWallpaperOpenChanged() { if (UiState.wallpaperOpen) { Appearance.pickerOpen = false; Style.variantOpen = false } }
        function onCaptureOpenChanged() { if (UiState.captureOpen) { Appearance.pickerOpen = false; Style.variantOpen = false } }
        function onRecMenuOpenChanged() { if (UiState.recMenuOpen) { Appearance.pickerOpen = false; Style.variantOpen = false } }
    }

    // qs ipc call settings toggle | open | close | page appearance|bar|notifications|wallpaper|displays|network|bluetooth|audio|power|keys|about
    IpcHandler {
        target: "settings"

        function toggle(): void { Settings.toggle() }
        function open(): void { Settings.show("") }
        function close(): void { Settings.open = false }
        function page(name: string): void { Settings.show(name) }
    }

    // qs ipc call power toggle
    IpcHandler {
        target: "power"

        function toggle(): void { Power.toggle() }
        function open(): void { Power.open() }
        function close(): void { Power.close() }
    }

    // qs ipc call dnd toggle | on | off | minutes 60   (do not disturb)
    IpcHandler {
        target: "dnd"

        function toggle(): void { NotifCenter.toggleDnd() }
        function on(): void { NotifCenter.setDnd(true, 0) }
        function off(): void { NotifCenter.setDnd(false, 0) }
        function minutes(m: int): void { NotifCenter.setDnd(true, m) }
    }

    // qs ipc call gamemode toggle
    IpcHandler {
        target: "gamemode"

        function toggle(): void { GameMode.toggle() }
        function on(): void { GameMode.set(true) }
        function off(): void { GameMode.set(false) }
    }

    // qs ipc call powersaver toggle
    IpcHandler {
        target: "powersaver"

        function toggle(): void { PowerSaver.toggle() }
        function on(): void { PowerSaver.set(true) }
        function off(): void { PowerSaver.set(false) }
    }

    // qs ipc call workspaces peek     (appare e si ritira)
    // qs ipc call workspaces toggle   (stays pinned until you repeat it)
    IpcHandler {
        target: "workspaces"

        function show(): void { Workspaces.flash(2600) }
        function peek(): void { Workspaces.flash(2600) }
        function toggle(): void { Workspaces.togglePin() }
    }

    // Work the same in all four styles (Island, Classic, Dashboard, Vertical):
    // qs ipc call capture toggle      (opens the menu, or stops the recording)
    // qs ipc call capture open        (opens the menu)
    // qs ipc call capture recscreen   (record the screen: starts, and stops if already recording)
    // qs ipc call capture recarea     (record an area: starts, and stops if already recording)
    // qs ipc call capture stop        (stops the recording)
    // qs ipc call capture pause       (pause / resume the recording)
    // qs ipc call capture shotscreen | shotarea | shotwindow     (screenshots)
    // qs ipc call capture audio off|mic|system|both              (audio of the next recording)
    IpcHandler {
        target: "capture"

        function toggle(): void { Capture.toggle() }
        function open(): void { Capture.open() }
        function stop(): void { Capture.stopRecording() }
        function pause(): void { Capture.togglePause() }
        function recscreen(): void { if (Capture.recording) Capture.stopRecording(); else Capture.run("rec-screen") }
        function recarea(): void { if (Capture.recording) Capture.stopRecording(); else Capture.run("rec-area") }
        function shotscreen(): void { Capture.run("shot-screen") }
        function shotarea(): void { Capture.run("shot-area") }
        function shotwindow(): void { Capture.run("shot-window") }
        function audio(mode: string): void {
            if (["off", "mic", "system", "both"].indexOf(mode) >= 0) Capture.audioMode = mode
        }
    }

    // qs ipc call calendar test    (sends a test reminder)
    // qs ipc call calendar check   (controlla subito i promemoria in scadenza)
    IpcHandler {
        target: "calendar"

        function test(): void { Notes.test() }
        function check(): void { Notes.check() }
    }

    // qs ipc call layout next | previous | test
    IpcHandler {
        target: "layout"

        function next(): void { KbLayout.next() }
        function previous(): void { KbLayout.previous() }
        function test(): void { KbLayout.test() }
    }

    // qs ipc call style toggle | open | close | set classic | set island
    IpcHandler {
        target: "style"

        function toggle(): void { Style.togglePicker() }
        function open(): void { Style.pickerOpen = true }
        function close(): void { Style.pickerOpen = false }
        function set(name: string): void { Style.set(name) }
        // qs ipc call style variant                 (opens / closes the Dashboard version selector)
        // qs ipc call style setvariant attached     (or: pill)
        function variant(): void {
            if (Style.variantOpen) Style.variantOpen = false
            else Style.openVariants(Compositor.focusedMonitor)
        }
        function setvariant(name: string): void { Style.setDashVariant(name) }
    }

    // qs ipc call audio dump   (writes the PipeWire nodes the shell sees to the log)
    // qs ipc call theme toggle        (opens the theme selector)
    // qs ipc call theme set <name>    (classic vivid complement triad analog mono tinted sober contrast neon)
    // qs ipc call theme mode light|dark|toggle   (also repaints the terminal and Firefox through pywal)
    IpcHandler {
        target: "theme"

        function toggle(): void { if (Appearance.pickerOpen) Appearance.pickerOpen = false; else Appearance.open(Compositor.focusedMonitor) }
        function open(): void { Appearance.open(Compositor.focusedMonitor) }
        function close(): void { Appearance.pickerOpen = false }
        function set(name: string): void { Appearance.setTheme(name) }
        function mode(m: string): void { Appearance.setMode(m) }
    }

    IpcHandler {
        target: "audio"

        function dump(): void { Audio.dump() }
    }

    // qs ipc call system open | toggle | hide   (resources pill)
    IpcHandler {
        target: "system"

        function show(): void { SysStats.show(6000) }
        function open(): void { SysStats.show(6000) }
        function toggle(): void { SysStats.togglePin() }
        function hide(): void { SysStats.hide() }
    }

    // qs ipc call lock lock   (locks the screen)
    // qs ipc call lock test   (safe test: unlocks itself after 12 seconds)
    IpcHandler {
        target: "lock"

        function lock(): void {
            UiState.lockTest = false
            UiState.locked = true
        }

        function test(): void {
            UiState.lockTestLeft = 12
            UiState.lockTest = true
            UiState.locked = true
        }
    }
}
