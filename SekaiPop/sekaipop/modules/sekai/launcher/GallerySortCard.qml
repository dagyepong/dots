import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The sort menu: a small white card in the shell's outline + hard-shadow
// style that drops down under the header's Sort chip — six orders, with a
// check beside the active one. Purely a display and a signal: `sortMode` in is
// what's actually active, selected(mode) out is a request; the picker
// decides whether/how to apply it (see WallpaperFace.qml's
// resortWallpapers() for why re-sorting never touches the folder or the
// Refresh dot).
Item {
    id: root

    property string sortMode: "date_desc"
    property var options: []     // [{ mode, label, short }]
    property bool shown: false

    signal selected(string mode)

    readonly property real rowH: 36
    readonly property real headH: 30

    width: 250
    height: headH + options.length * rowH + 12

    visible: opacity > 0.01
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.94
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        x: Theme.shadowOffset
        y: Theme.shadowOffset
        width: parent.width
        height: parent.height
        radius: Theme.radiusOuter
        color: Theme.lineShadow
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusOuter
        color: "#ffffff"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        // eats clicks on the card's own padding
        MouseArea { anchors.fill: parent }

        Text {
            x: 16
            y: 9
            text: "SORT BY"
            color: ScrapbookTheme.inkSoft
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyleBold
            font.weight: Font.ExtraBold
            font.pixelSize: 11
            font.letterSpacing: 1.2
        }

        Column {
            x: 6
            y: root.headH
            width: parent.width - 12

            Repeater {
                model: root.options
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool active: modelData.mode === root.sortMode

                    width: parent.width
                    height: root.rowH
                    radius: 8
                    color: rowArea.containsMouse ? Theme.colHoverTint : "transparent"

                    MaterialIcon {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        size: 20
                        weight: 600
                        color: Theme.colBorder
                        visible: row.active
                    }

                    Text {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.styleName: row.active ? Theme.fontStyleBold : ""
                        font.weight: row.active ? Font.ExtraBold : Font.Medium
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(row.modelData.mode)
                    }
                }
            }
        }
    }
}
