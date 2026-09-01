pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live wallpaper-derived palette. wallcolors.py writes a small colour JSON from
 * hyprpaper's current wallpaper and this singleton watches it. Defaults are a
 * neutral monochrome fallback so the pill still renders before the first palette
 * file exists.
 */
Singleton {
    id: root

    readonly property string surface: adapter.surface
    readonly property string surfaceContainer: adapter.surface_container
    readonly property string surfaceContainerLow: adapter.surface_container_low
    readonly property string surfaceContainerHigh: adapter.surface_container_high
    readonly property string surfaceContainerHighest: adapter.surface_container_highest
    readonly property string primary: adapter.primary
    readonly property string primaryContainer: adapter.primary_container
    readonly property string onPrimaryContainer: adapter.on_primary_container
    readonly property string outline: adapter.outline
    readonly property string outlineVariant: adapter.outline_variant
    readonly property string cream: adapter.cream
    readonly property string bright: adapter.bright
    readonly property string subtle: adapter.subtle
    readonly property string dim: adapter.dim
    readonly property string faint: adapter.faint
    readonly property string iconDim: adapter.icon_dim
    readonly property string tickRest: adapter.tick_rest

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string surface: "#151515"
            property string surface_container: "#202020"
            property string surface_container_low: "#1b1b1b"
            property string surface_container_high: "#292929"
            property string surface_container_highest: "#363636"
            property string primary: "#d0d0d0"
            property string primary_container: "#5a5a5a"
            property string on_primary_container: "#f2f2f2"
            property string outline: "#8e8e8e"
            property string outline_variant: "#3f3f3f"
            property string cream: "#eeeeee"
            property string bright: "#ffffff"
            property string subtle: "#c6c6c6"
            property string dim: "#8e8e8e"
            property string faint: "#686868"
            property string icon_dim: "#d0d0d0"
            property string tick_rest: "#bfbfbf"
        }
    }
}
