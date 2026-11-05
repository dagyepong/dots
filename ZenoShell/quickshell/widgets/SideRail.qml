import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import qs.theme
import qs.services

// The bar of the "Vertical" style: flush against the left edge, drawn by the ScreenFrame behind it.
//   top    -> launcher · workspaces
//   center -> music · clock (calendar)
//   bottom -> notifications · tools · wifi · bluetooth · sound · battery · power
// Every button opens its own panel, attached to the bar (Popouts).
Item {
    id: root

    property string screenName: ""
    property string current: ""             // panel that is open, to highlight its button
    readonly property bool hovered: hover.hovered

    signal request(string name, real cy)    // click on a button
    signal peek(string name, real cy)       // mouse over a button: its panel opens
    signal unpeek()                         // the mouse left the button

    readonly property var dots: Compositor.dotsFor(screenName)
    readonly property int activeId: Compositor.activeIdFor(screenName)
    readonly property var bt: Bluetooth.defaultAdapter

    // Border flash is replaced here by a dot on the bell
    HoverHandler { id: hover }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function two(n) { return (n < 10 ? "0" : "") + n }

    // ---------- Top ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        spacing: 10

        RailButton {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: "grid"
            glyphSize: 15
            active: root.current === "launcher"
            onActivated: cy => root.request("launcher", cy)
            onEntered: cy => root.peek("launcher", cy)
            onExited: root.unpeek()
        }

        // Workspaces: vertical pills, the active one is taller (a click switches to it)
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
                model: Math.min(root.dots.length, 8)

                delegate: Rectangle {
                    id: ws

                    required property int index
                    readonly property bool active: root.dots[index].id === root.activeId

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 7
                    height: active ? 24 : 9
                    radius: 3.5
                    color: active ? Theme.accent
                           : (root.dots[index].occupied ? Theme.foreground : Theme.mix(Theme.island, Theme.foreground, 0.22))
                    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Compositor.focusWorkspace(root.dots[ws.index].id)
                    }
                }
            }
        }
    }

    // ---------- Center: music + clock ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 - height / 2
        spacing: 12

        // Music: cover (opens the music panel)
        Item {
            id: coverBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34; height: 34
            visible: Media.active

            Rectangle {
                anchors.fill: parent
                radius: 17
                color: "transparent"
                border.width: 2
                border.color: root.current === "media" || Media.playing ? Theme.accent : "transparent"
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }

            ClippingRectangle {
                anchors.centerIn: parent
                width: 28; height: 28
                radius: 14
                color: Theme.surfaceSoft
                opacity: Media.playing ? 1 : 0.6

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(64, 64)
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.request("media", coverBtn.mapToItem(null, 0, 17).y)
                onEntered: root.peek("media", coverBtn.mapToItem(null, 0, 17).y)
                onExited: root.unpeek()
            }
        }

        // Clock (opens the calendar)
        Item {
            id: clockBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: 38
            height: clockCol.implicitHeight + 12

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.current === "calendar" ? Theme.accent : (clockMouse.containsMouse ? Theme.islandHover : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Column {
                id: clockCol
                anchors.centerIn: parent
                spacing: 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Capture.recording
                    width: 7; height: 7
                    radius: 3.5
                    color: Capture.paused ? Theme.muted : Theme.danger
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Settings.clock24 ? root.two(clock.date.getHours()) : String(clock.date.getHours() % 12 || 12)
                    color: root.current === "calendar" ? Theme.island : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.two(clock.date.getMinutes())
                    color: root.current === "calendar" ? Theme.island : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !Settings.clock24
                    text: clock.date.getHours() < 12 ? "AM" : "PM"
                    color: root.current === "calendar" ? Theme.island : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 3
                    text: Qt.locale("en_US").toString(clock.date, "ddd").toUpperCase()
                    color: root.current === "calendar" ? Theme.island : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clock.date.getDate()
                    color: root.current === "calendar" ? Theme.island : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.request("calendar", clockBtn.mapToItem(null, 0, clockBtn.height / 2).y)
                onEntered: root.peek("calendar", clockBtn.mapToItem(null, 0, clockBtn.height / 2).y)
                onExited: root.unpeek()
            }
        }
    }

    // ---------- Bottom ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        spacing: 2

        // Recording: opens the capture menu; while recording it shows the time and opens the recording menu
        Item {
            id: recBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34
            height: Capture.recording ? 48 : 34

            readonly property string panelName: Capture.recording ? "record" : "capture"
            readonly property bool open: root.current === "record" || root.current === "capture"

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: recBtn.open ? Theme.accent : (recMouse.containsMouse ? Theme.islandHover : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Column {
                anchors.centerIn: parent
                spacing: 3

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    kind: "record"
                    size: 16
                    color: recBtn.open ? Theme.island : (Capture.recording ? (Capture.paused ? Theme.muted : Theme.danger) : Theme.foreground)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Capture.recording
                    text: Capture.timeText
                    color: recBtn.open ? Theme.island : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            MouseArea {
                id: recMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.request(recBtn.panelName, recBtn.mapToItem(null, 0, recBtn.height / 2).y)
                onEntered: root.peek(recBtn.panelName, recBtn.mapToItem(null, 0, recBtn.height / 2).y)
                onExited: root.unpeek()
            }
        }

        RailButton {
            icon: "bell"
            active: root.current === "notifs"
            badge: NotifCenter.unread || NotifCenter.count > 0
            onActivated: cy => root.request("notifs", cy)
            onEntered: cy => root.peek("notifs", cy)
            onExited: root.unpeek()
        }

        RailButton {
            icon: "gear"
            active: root.current === "tools"
            onActivated: cy => root.request("tools", cy)
            onEntered: cy => root.peek("tools", cy)
            onExited: root.unpeek()
        }

        RailButton {
            icon: "wifi"
            level: Network.level
            tone: Network.wifiOn ? (Network.connected ? Theme.accent : Theme.foreground) : Theme.muted
            active: root.current === "wifi"
            onActivated: cy => root.request("wifi", cy)
            onEntered: cy => root.peek("wifi", cy)
            onExited: root.unpeek()
        }

        RailButton {
            icon: "bluetooth"
            tone: root.bt && root.bt.enabled ? Theme.foreground : Theme.muted
            active: root.current === "bluetooth"
            onActivated: cy => root.request("bluetooth", cy)
            onEntered: cy => root.peek("bluetooth", cy)
            onExited: root.unpeek()
        }

        RailButton {
            icon: "volume"
            level: Audio.muted ? 0 : (Audio.volume > 0.5 ? 2 : 1)
            tone: Audio.muted ? Theme.muted : Theme.foreground
            active: root.current === "sound"
            onActivated: cy => root.request("sound", cy)
            onEntered: cy => root.peek("sound", cy)
            onExited: root.unpeek()
        }

        // Battery + quick settings
        Item {
            id: batBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34; height: 44
            visible: Battery.present

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.current === "quick" ? Theme.accent : (batMouse.containsMouse ? Theme.islandHover : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Column {
                anchors.centerIn: parent
                spacing: 3

                BatteryIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    percent: Battery.percent
                    charging: Battery.charging
                    outline: root.current === "quick" ? Theme.island : Battery.tone
                    fillColor: root.current === "quick" ? Theme.island : Battery.tone
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(Battery.percent * 100)
                    color: root.current === "quick" ? Theme.island : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }
            }

            MouseArea {
                id: batMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.request("quick", batBtn.mapToItem(null, 0, 22).y)
                onEntered: root.peek("quick", batBtn.mapToItem(null, 0, 22).y)
                onExited: root.unpeek()
            }
        }

        // Quick settings without a battery (desktop)
        RailButton {
            visible: !Battery.present
            icon: "sun"
            active: root.current === "quick"
            onActivated: cy => root.request("quick", cy)
            onEntered: cy => root.peek("quick", cy)
            onExited: root.unpeek()
        }

        RailButton {
            icon: "power"
            active: root.current === "power"
            onActivated: cy => root.request("power", cy)
        }
    }
}
