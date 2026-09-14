// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G S   H E R O                                              │
// │   settings page heading                                                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// Settings page header: mark and name, left-aligned, a step larger than the
// group headings.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""

    spacing: 10

    Text {
        Layout.leftMargin: 4
        text: root.icon
        font.family: Theme.fontMono
        font.pixelSize: 17
        color: Theme.accent
    }

    Text {
        Layout.fillWidth: true
        text: root.title
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        color: Theme.text
    }
}
