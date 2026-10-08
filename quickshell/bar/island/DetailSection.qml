// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E T A I L   S E C T I O N                                            │
// │   a titled group of rows on a control-centre page                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"

// A title in small capitals, then rows `Theme.detailRowGap` apart; its height
// is `Theme.detailSection`, which the services declare their pages with.
ColumnLayout {
    id: root

    property string title: ""
    default property alias rows: list.data

    Layout.fillWidth: true
    spacing: 0

    Text {
        Layout.preferredHeight: Theme.detailTitle
        verticalAlignment: Text.AlignVCenter
        text: root.title
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        color: Theme.textMuted
    }

    Column {
        id: list

        Layout.fillWidth: true
        spacing: Theme.detailRowGap
    }
}
