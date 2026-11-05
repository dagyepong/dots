import QtQuick
import qs.theme
import qs.services

// Panel: notifications and do-not-disturb
Item {
    id: root

    width: 340
    height: 420

    Rectangle {
        x: 10; y: 10
        width: parent.width - 20
        height: parent.height - 20
        radius: 22
        color: Theme.surfaceSoft

        Text {
            x: 18; y: 16
            text: "Notifications"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: NotifCenter.count > 0 ? 62 : 14
            y: 12
            width: 28; height: 28
            radius: 14
            color: NotifCenter.dnd ? Theme.accent : (dndMouse.containsMouse ? Theme.islandHover : Theme.island)
            Behavior on color { ColorAnimation { duration: 120 } }

            Glyph {
                anchors.centerIn: parent
                kind: "focus"
                size: 14
                color: NotifCenter.dnd ? Theme.island : Theme.foreground
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotifCenter.toggleDnd()
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 20
            visible: NotifCenter.count > 0
            text: "Clear"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: NotifCenter.clearAll()
            }
        }

        Text {
            x: 0; y: 48
            width: parent.width
            height: parent.height - 48
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: NotifCenter.count === 0
            text: NotifCenter.dnd ? "Do not disturb\n" + NotifCenter.dndText : "No notifications"
            color: Theme.muted
            opacity: 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        ListView {
            x: 10; y: 48
            width: parent.width - 20
            height: parent.height - 48 - 10
            spacing: 6
            clip: true
            model: NotifCenter.list

            delegate: Rectangle {
                id: nItem

                required property var modelData

                width: ListView.view.width
                height: nText.implicitHeight + 16
                radius: 14
                color: Theme.island

                Column {
                    id: nText
                    x: 12; y: 8
                    width: parent.width - 24 - 16
                    spacing: 2

                    Text {
                        width: parent.width
                        text: nItem.modelData.appName
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: nItem.modelData.summary
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: nItem.modelData.body
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        textFormat: Text.StyledText
                        maximumLineCount: 3
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    y: 5
                    text: "×"
                    color: Theme.muted
                    font.pixelSize: 16

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nItem.modelData.dismiss()
                    }
                }
            }
        }
    }

    onVisibleChanged: if (visible) NotifCenter.unread = false
}
