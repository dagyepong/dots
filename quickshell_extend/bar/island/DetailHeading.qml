// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E T A I L   H E A D I N G                                            │
// │   a control-centre page's title · back, name and what it is set to       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../components"

// The top of a page the control centre opens into: the way back, the page's
// name, and under it what it is set to now.
RowLayout {
    id: root

    property string title: ""
    property string detail: ""

    signal back()

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.detailHeader
    spacing: 10

    IconButton {
        icon: "󰅁"
        iconSize: 14
        onClicked: root.back()
    }

    ColumnLayout {
        spacing: 1

        Text {
            text: root.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Text {
            visible: text !== ""
            text: root.detail
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.textMuted
        }
    }

    Item { Layout.fillWidth: true }
}
