import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    property var today: new Date()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            model: 5

            Item {
                id: cell

                readonly property var d: new Date(root.today.getFullYear(),
                                                  root.today.getMonth(),
                                                  root.today.getDate() + index - 2)
                readonly property bool isToday: index === 2
                readonly property bool weekend: d.getDay() === 0 || d.getDay() === 6

                width: 42
                height: col.implicitHeight

                Column {
                    id: col
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lbl.implicitWidth + 10
                        height: 16
                        radius: 8
                        color: cell.isToday ? Theme.border : "transparent"

                        Text {
                            id: lbl
                            anchors.centerIn: parent
                            text: cell.isToday
                                  ? Qt.locale("en_US").dayName(cell.d.getDay(), Locale.ShortFormat).toUpperCase()
                                  : Qt.locale("en_US").dayName(cell.d.getDay(), Locale.NarrowFormat).toUpperCase()
                            color: cell.isToday ? Theme.foreground
                                                : (cell.weekend ? Theme.danger : Theme.muted)
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cell.d.getDate()
                        color: cell.isToday ? Theme.accent
                                            : (Notes.count(Notes.keyOf(cell.d)) > 0 ? Theme.note
                                               : (cell.weekend ? Theme.danger : Theme.muted))
                        font.pixelSize: 15
                        font.bold: cell.isToday || Notes.count(Notes.keyOf(cell.d)) > 0
                    }
                }
            }
        }
    }
}
