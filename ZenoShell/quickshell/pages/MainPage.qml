import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.theme
import qs.services
import qs.widgets

Item {
    id: root

    signal openPage(string name)
    signal powerRequested()

    property bool gameMode: false
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool dragging: soundSlider.pressed || displaySlider.pressed
    readonly property int notifY: Battery.present ? 302 : 238
    property real listTop: 28 + 38 + (NotifCenter.dnd ? 30 : 0)
    Behavior on listTop { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    width: 360

    // Row 1
    ControlTile {
        x: 14; y: 14
        width: 135
        icon: "wifi"
        iconLevel: Network.level
        title: "Wi-Fi"
        subtitle: !Network.wifiOn ? "Off" : (Network.connected ? Network.ssid : "Not connected")
        active: Network.wifiOn
        onClicked: root.openPage("wifi")
    }

    ControlTile {
        x: 157; y: 14
        width: 135
        icon: "leaf"
        title: "Power Saver"
        subtitle: PowerSaver.on ? "On" : "Off"
        active: PowerSaver.on
        onClicked: PowerSaver.toggle()
    }

    ControlCircle {
        x: 300; y: 14
        icon: "power"
        onClicked: root.powerRequested()
    }

    // Row 2
    ControlTile {
        x: 14; y: 68
        width: 135
        icon: "bluetooth"
        title: "Bluetooth"
        subtitle: root.bt ? (root.bt.enabled ? "On" : "Off") : "Unavailable"
        active: root.bt ? root.bt.enabled : false
        onClicked: root.openPage("bluetooth")
    }

    ControlTile {
        x: 157; y: 68
        width: 135
        icon: "game"
        title: "Game Mode"
        subtitle: GameMode.on ? "On" : "Off"
        active: GameMode.on
        onClicked: GameMode.toggle()
    }

    ControlCircle {
        x: 300; y: 68
        icon: "moon"
        active: NightLight.on
        onClicked: NightLight.toggle()
    }

    // Sound
    Rectangle {
        x: 14; y: 122
        width: 332
        height: 52
        radius: 16
        color: Theme.surfaceSoft

        Text {
            x: 14; y: 7
            text: "Sound"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 2
            text: "›"
            color: Theme.muted
            font.pixelSize: 16
        }

        MouseArea {
            width: parent.width
            height: 24
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPage("sound")
        }

        SliderBar {
            id: soundSlider
            x: 12; y: 24
            width: parent.width - 24
            value: Math.min(1, Audio.volume)
            icon: "volume"
            iconLevel: Audio.muted ? 0 : (Audio.volume > 0.5 ? 2 : 1)
            onMoved: v => Audio.setVolume(v)
        }
    }

    // Display (the header opens the page)
    Rectangle {
        x: 14; y: 180
        width: 332
        height: 52
        radius: 16
        color: Theme.surfaceSoft

        Text {
            x: 14; y: 7
            text: "Display"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 2
            text: "›"
            color: Theme.muted
            font.pixelSize: 16
        }

        MouseArea {
            width: parent.width
            height: 24
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPage("display")
        }

        SliderBar {
            id: displaySlider
            x: 12; y: 24
            width: parent.width - 24
            value: Brightness.percent
            icon: "sun"
            enabled: Brightness.available
            opacity: Brightness.available ? 1 : 0.4
            onMoved: v => Brightness.setPercent(v)
        }
    }

    // Battery
    Rectangle {
        x: 14; y: 238
        width: 332
        height: 56
        radius: 16
        color: Theme.surfaceSoft
        visible: Battery.present

        Text {
            x: 14; y: 7
            text: "Battery"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 7
            text: Battery.statusText + (Battery.timeText !== "" ? " · " + Battery.timeText : "")
            color: Battery.tone
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        BatteryIcon {
            x: 14; y: 31
            percent: Battery.percent
            charging: Battery.charging
            outline: Battery.tone
            fillColor: Battery.tone
        }

        Rectangle {
            x: 46; y: 31
            width: parent.width - 46 - 14 - 44
            height: 12
            radius: 6
            color: Theme.island

            Rectangle {
                width: Math.max(parent.height, parent.width * Battery.percent)
                height: parent.height
                radius: parent.radius
                color: Battery.tone
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 31
            height: 12
            verticalAlignment: Text.AlignVCenter
            text: Math.round(Battery.percent * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }
    }

    // Notifiche
    Rectangle {
        x: 14; y: root.notifY
        width: 332
        height: root.height - root.notifY - 14
        radius: 16
        color: Theme.surfaceSoft

        Text {
            x: 14; y: 8
            text: "Notifications"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 8
            text: "Clear all"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            visible: NotifCenter.count > 0

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: NotifCenter.clearAll()
            }
        }

        // ---- Non disturbare ----
        Rectangle {
            x: 8; y: 26
            width: parent.width - 16
            height: 34
            radius: 17
            color: Theme.island

            Rectangle {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26
                radius: 13
                color: NotifCenter.dnd ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: 140 } }

                Glyph {
                    anchors.centerIn: parent
                    kind: "focus"
                    size: 13
                    color: NotifCenter.dnd ? Theme.island : Theme.foreground
                }
            }

            Column {
                x: 38
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: "Do not disturb"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    text: NotifCenter.dndText
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }
            }

            Toggle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                checked: NotifCenter.dnd
                onToggled: NotifCenter.toggleDnd()
            }
        }

        // Duration (shown when active)
        Row {
            x: 8; y: 64
            spacing: 5
            visible: NotifCenter.dnd
            opacity: NotifCenter.dnd ? 1 : 0

            Repeater {
                model: [{ l: "30 min", m: 30 }, { l: "1 h", m: 60 }, { l: "2 h", m: 120 }, { l: "∞", m: 0 }]

                delegate: Chip {
                    required property var modelData

                    width: (332 - 16 - 15) / 4
                    height: 24
                    label: modelData.l
                    selected: NotifCenter.dndMinutes === modelData.m
                    onClicked: NotifCenter.setDnd(true, modelData.m)
                }
            }
        }

        Text {
            x: 0
            y: root.listTop
            width: parent.width
            height: parent.height - root.listTop
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "No notifications"
            color: Theme.muted
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: 11
            visible: NotifCenter.count === 0
        }

        ListView {
            x: 8; y: root.listTop
            width: parent.width - 16
            height: parent.height - root.listTop - 8
            spacing: 6
            clip: true
            model: NotifCenter.list

            delegate: Rectangle {
                id: item

                required property var modelData

                width: ListView.view.width
                height: textCol.implicitHeight + 16
                radius: 12
                color: Theme.island

                Rectangle {
                    x: 8; y: 8
                    width: 22; height: 22
                    radius: 11
                    color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: (item.modelData.appName || "?").charAt(0).toUpperCase()
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                Column {
                    id: textCol
                    x: 38; y: 8
                    width: parent.width - 38 - 28
                    spacing: 1

                    Text {
                        width: parent.width
                        text: item.modelData.appName
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: item.modelData.summary
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: item.modelData.body
                        visible: text !== ""
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
                    anchors.rightMargin: 10
                    y: 6
                    text: "×"
                    color: Theme.muted
                    font.pixelSize: 16

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: item.modelData.dismiss()
                    }
                }
            }
        }
    }
}
