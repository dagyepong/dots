import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A small leaning key for the Settings header: "back to the menu" and the
// six page-jump chips that sit next to it while a page is open. Icon only,
// or icon and name when `label` is set. It is a SekaiKey, so it presses into
// its shadow, springs back, and is lit (the accent wipe) while `selected`.
//
// Pure UI: whoever places it turns clicked() into an action. `badge` is a
// pink dot ("something is waiting", used on About when an update exists).
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    property bool badge: false
    property real minWidth: 50

    signal clicked()

    readonly property bool hovered: area.containsMouse

    readonly property real capH: 46
    readonly property real capW: Math.max(minWidth, row.implicitWidth + 24)

    implicitWidth: capW + 7
    implicitHeight: capH + 4

    SekaiKey {
        id: key

        capW: root.capW
        capH: root.capH
        skew: 0.24 * Theme.settingsLean
        radius: 17
        lit: root.selected
        hovered: root.hovered
        pressed: area.pressed
        flatShadow: Theme.quickFlat
        ringExtra: 5

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 9

            MaterialIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                name: root.icon
                fill: Theme.iconFill
                color: key.ink
            }

            Text {
                visible: root.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        Rectangle {
            visible: root.badge
            x: key.capW - 22
            y: -5
            width: 15
            height: 15
            radius: 7.5
            color: ScrapbookTheme.accentPink
            border.width: 2.5
            border.color: Theme.pLine
            antialiasing: true
        }
    }

    // A sibling of the key, not inside it: the cap moves while pressed and a
    // MouseArea riding along would slide out from under a click on its edge.
    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.capW
        height: root.capH
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
