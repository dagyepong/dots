import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    property int sel: 0
    property string armed: ""          // action awaiting confirmation

    readonly property var actions: [
        { id: "lock",     label: "Lock",     icon: "lock",   danger: false },
        { id: "logout",   label: "Logout",   icon: "logout", danger: true },
        { id: "suspend",  label: "Suspend",  icon: "moon",   danger: false },
        { id: "reboot",   label: "Reboot",   icon: "reboot", danger: true },
        { id: "shutdown", label: "Shutdown", icon: "power",  danger: true }
    ]

    function reset() {
        sel = 0
        armed = ""
        keys.forceActiveFocus()
    }

    function activate(i) {
        const a = actions[i]
        if (a.danger && armed !== a.id) {      // first click: asks for confirmation
            armed = a.id
            armTimer.restart()
            return
        }
        armTimer.stop()
        armed = ""
        Power.run(a.id)
    }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: root.armed = ""
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Right) {
                root.sel = (root.sel + 1) % root.actions.length
                root.armed = ""
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                root.sel = (root.sel + root.actions.length - 1) % root.actions.length
                root.armed = ""
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.activate(root.sel)
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                Power.close()
                event.accepted = true
            }
        }
    }

    Text {
        x: 24; y: 20
        text: "Power"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 24
        text: "← →  ·  Enter  ·  Esc"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Row {
        x: (root.width - width) / 2
        y: 62
        spacing: 11

        Repeater {
            model: root.actions

            delegate: Rectangle {
                id: tile

                required property var modelData
                required property int index

                readonly property bool selected: root.sel === index
                readonly property bool isArmed: root.armed === modelData.id

                width: 78
                height: 86
                radius: 22
                color: isArmed ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.18)
                               : (selected ? Theme.islandHover : Theme.surfaceSoft)
                border.width: (isArmed || selected) ? 1.5 : 0
                border.color: isArmed ? Theme.danger : Theme.accent
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    x: (parent.width - width) / 2
                    y: 12
                    width: 38; height: 38
                    radius: 19
                    color: tile.isArmed ? Theme.danger : (tile.selected ? Theme.accent : Theme.border)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Glyph {
                        anchors.centerIn: parent
                        kind: tile.modelData.icon
                        size: 18
                        color: (tile.isArmed || tile.selected) ? Theme.island : Theme.foreground
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 60
                    text: tile.isArmed ? "Confirm?" : tile.modelData.label
                    color: tile.isArmed ? Theme.danger : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: tile.isArmed
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.sel = tile.index
                    onClicked: root.activate(tile.index)
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 160
        text: root.armed !== "" ? "Press again to confirm" : "Logout, Reboot and Shutdown ask for confirmation"
        color: root.armed !== "" ? Theme.danger : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
}
