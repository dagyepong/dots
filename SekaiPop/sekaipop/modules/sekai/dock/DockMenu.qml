import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The right-click menu of a dock key (Dock.qml): a card of rows, each an icon
// and a label. `rows` is a list of { id, label, icon } (or { sep: true } for a
// line between groups, or { header: "text" } for a title); a row with
// `danger: true` is drawn in red. Picking one emits picked(id).
DockCard {
    id: root

    property var rows: []
    signal picked(string id)

    readonly property real rowH: 36
    readonly property real menuW: 236

    contentWidth: root.menuW
    contentHeight: col.implicitHeight

    Column {
        id: col
        x: root.pad
        y: root.pad
        width: root.menuW
        spacing: 2

        Repeater {
            model: root.rows

            delegate: Item {
                id: row
                required property var modelData

                readonly property bool isSep: row.modelData.sep === true
                readonly property bool isHeader: row.modelData.header !== undefined

                width: root.menuW
                height: row.isSep ? 9 : (row.isHeader ? 30 : root.rowH)

                Rectangle {
                    visible: row.isSep
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Theme.surfaceDivider
                }

                Text {
                    visible: row.isHeader
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    width: parent.width - 16
                    elide: Text.ElideRight
                    text: row.isHeader ? row.modelData.header : ""
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Rectangle {
                    visible: !row.isSep && !row.isHeader
                    anchors.fill: parent
                    radius: 10
                    color: rowArea.containsMouse
                        ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, rowArea.pressed ? 0.34 : 0.2)
                        : "transparent"
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }

                    MaterialIcon {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon ?? ""
                        size: 20
                        color: row.modelData.danger === true ? "#e0575b" : Theme.ink
                    }

                    Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 52
                        elide: Text.ElideRight
                        text: row.modelData.label ?? ""
                        color: row.modelData.danger === true ? "#e0575b" : Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: rowArea
                    enabled: !row.isSep && !row.isHeader
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(row.modelData.id)
                }
            }
        }
    }
}
