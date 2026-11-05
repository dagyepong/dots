import QtQuick
import qs.theme
import qs.services

Column {
    id: root

    property int year: 2000
    property int month: 0
    property var today: new Date()

    signal dayClicked(var date)

    property int cellW: 38
    property int cellH: 34
    readonly property int offset: (new Date(year, month, 1).getDay() - Theme.weekStart + 7) % 7

    spacing: 6

    // Day header
    Row {
        Repeater {
            model: 7

            Text {
                width: root.cellW
                height: 20
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Qt.locale("en_US").dayName((Theme.weekStart + index) % 7, Locale.NarrowFormat).toUpperCase()
                color: Theme.muted
                font.pixelSize: root.cellW < 34 ? 9 : 11
                font.bold: true
            }
        }
    }

    // Days
    Grid {
        columns: 7

        Repeater {
            model: 42

            Item {
                id: cell

                readonly property var d: new Date(root.year, root.month, 1 - root.offset + index)
                readonly property bool inMonth: d.getMonth() === root.month
                readonly property bool isToday: d.getFullYear() === root.today.getFullYear()
                                                && d.getMonth() === root.today.getMonth()
                                                && d.getDate() === root.today.getDate()
                readonly property bool hasNotes: Notes.count(Notes.keyOf(d)) > 0

                width: root.cellW
                height: root.cellH

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(30, root.cellH - 3)
                    height: width
                    radius: width / 2
                    color: cell.isToday ? Theme.accent
                           : (cell.hasNotes ? Theme.note
                              : (mouse.containsMouse ? Theme.islandHover : "transparent"))
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Today with notes: dot in the notes color
                Rectangle {
                    x: parent.width / 2 + 8
                    y: 3
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.note
                    border.width: 1.5
                    border.color: Theme.island
                    visible: cell.isToday && cell.hasNotes
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.d.getDate()
                    color: (cell.isToday || cell.hasNotes) ? Theme.island : Theme.foreground
                    opacity: (cell.inMonth || cell.isToday || cell.hasNotes) ? 1 : 0.35
                    font.pixelSize: root.cellW < 34 ? 11 : 13
                    font.bold: cell.isToday || cell.hasNotes
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dayClicked(cell.d)
                }
            }
        }
    }
}
