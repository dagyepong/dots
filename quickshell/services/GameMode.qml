pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property bool on: false
    property bool dndBefore: false

    // In Lua configs "hyprctl keyword" no longer exists: "hyprctl eval" is used
    readonly property string luaOff:
        "hl.config({ animations = { enabled = false }, "
        + "decoration = { blur = { enabled = false }, shadow = { enabled = false }, rounding = 0 }, "
        + "general = { gaps_in = 0, gaps_out = 0 } })"

    // niri: same things, but in a file included by config.kdl (see Compositor.tweak)
    readonly property string kdlOff:
        "animations { off; }\n"
        + "layout { gaps 0; shadow { off; } }\n"
        + "window-rule { geometry-corner-radius 0; background-effect { blur false; } }"

    function set(enable) {
        if (enable === on) return
        on = enable

        if (enable) {
            dndBefore = NotifCenter.dnd
            NotifCenter.setDnd(true, 0)
            Compositor.tweak(luaOff, kdlOff)
        } else {
            NotifCenter.setDnd(dndBefore, 0)
            Compositor.tweakReset()    // restores the original config
        }
    }

    function toggle() { set(!on) }
}
