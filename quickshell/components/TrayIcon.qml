// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   I C O N                                                      │
// │   a tray item's icon · in grey, drawn for a dark bar                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects

// An item names its icon, and the shell's icon theme draws named panel icons
// dark, for a light bar. Papirus-Dark carries tray icons of its own, light
// ones, so a named icon is looked up there first and the item's own is the
// fallback. Either way it is drawn in grey: the drawing inside an icon
// survives, which a flat silhouette of a round icon would not.
Item {
    id: root

    // `SystemTrayItem.icon`: `image://icon/<name>` or a picture the item sent.
    property string icon: ""

    readonly property string named: {
        const found = /^image:\/\/icon\/([^?]+)/.exec(root.icon)
        return found ? found[1] : ""
    }

    readonly property string panelIcon: root.named !== ""
        ? `file:///usr/share/icons/Papirus-Dark/22x22/panel/${root.named}.svg` : ""

    property bool fallback: false
    onIconChanged: root.fallback = false

    Image {
        id: picture

        anchors.fill: parent
        sourceSize.width: root.width * 2
        sourceSize.height: root.height * 2
        source: root.panelIcon !== "" && !root.fallback ? root.panelIcon : root.icon
        visible: false
        onStatusChanged: {
            if (status === Image.Error && !root.fallback)
                root.fallback = true
        }
    }

    MultiEffect {
        anchors.fill: picture
        source: picture
        saturation: -1
        brightness: 0.1
    }
}
