import QtQuick
import qs.theme
import qs.services

// End of recording: asks for the file name (Enter saves, Esc keeps date and time)
Item {
    id: root

    implicitHeight: 172

    readonly property string defaultName: Capture.pendingPath.split("/").pop().replace(/\.mp4$/, "")

    function reset() {
        field.text = ""
        field.forceActiveFocus()
    }

    function save() { Capture.finishNaming(field.text) }
    function keep() { Capture.finishNaming("") }

    // ---------- Header ----------
    Rectangle {
        x: 20; y: 18
        width: 34; height: 34
        radius: 17
        color: Theme.border

        Glyph {
            anchors.centerIn: parent
            kind: "record"
            size: 17
            color: Theme.danger
        }
    }

    Text {
        x: 64; y: 18
        height: 34
        verticalAlignment: Text.AlignVCenter
        text: "Name your recording"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.bold: true
    }

    // ---------- Name ----------
    Rectangle {
        x: 20; y: 66
        width: root.width - 40
        height: 40
        radius: 20
        color: Theme.surfaceSoft
        border.width: field.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextInput {
            id: field

            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 54
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            clip: true
            selectByMouse: true

            onAccepted: root.save()
            Keys.onEscapePressed: root.keep()
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 54
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text === ""
            text: root.defaultName
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: ".mp4"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // ---------- Pulsanti ----------
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 120
        spacing: 8

        Rectangle {
            width: 90; height: 34
            radius: 17
            color: skipMouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "Skip"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            MouseArea {
                id: skipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.keep()
            }
        }

        Rectangle {
            width: 110; height: 34
            radius: 17
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: "Save"
                color: Theme.island
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.save()
            }
        }
    }

    Text {
        x: 24
        y: 128
        text: "Enter  ·  Esc keeps the date and time"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
}
