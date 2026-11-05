import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    readonly property var t: Toast.current
    readonly property bool isBattery: t ? t.kind === "battery" : false
    readonly property color tone: (t && t.tone === "danger") ? Theme.danger : Theme.accent

    implicitHeight: Math.max(70, 14 + textCol.implicitHeight + 14 + (isBattery ? 14 : 0))

    // Mouse over: the toast stays open
    HoverHandler {
        onHoveredChanged: Toast.paused = hovered
    }

    // Click: closes the toast (the notification stays in the control center)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Toast.dismiss()
    }

    Rectangle {
        x: 16; y: 16
        width: 38; height: 38
        radius: 19
        color: Theme.border

        Text {
            anchors.centerIn: parent
            visible: !root.isBattery
            text: (root.t ? root.t.app : "?").charAt(0).toUpperCase()
            color: root.tone
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.bold: true
        }

        BatteryIcon {
            anchors.centerIn: parent
            visible: root.isBattery
            percent: Battery.percent
            charging: Battery.charging
            outline: root.tone
            fillColor: root.tone
        }
    }

    Column {
        id: textCol
        x: 66; y: 14
        width: root.width - 66 - 36
        spacing: 2

        Text {
            width: parent.width
            text: root.t ? root.t.app : ""
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.t ? root.t.summary : ""
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.t ? root.t.body : ""
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: "×"
        color: Theme.muted
        font.pixelSize: 16
    }

    // Charge bar (battery warning only)
    Rectangle {
        visible: root.isBattery
        x: 66
        y: root.height - 18
        width: root.width - 66 - 20
        height: 5
        radius: 2.5
        color: Theme.border

        Rectangle {
            width: Math.max(5, parent.width * Battery.percent)
            height: parent.height
            radius: parent.radius
            color: root.tone
        }
    }
}
