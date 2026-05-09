import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

Item {
    id: root

    enum View { Settings, Wifi, Sound, Bluetooth, Power }

    required property var net
    required property var sink
    required property var battery

    property int view: SettingsContent.View.Settings
    readonly property bool showingWifi:      view === SettingsContent.View.Wifi
    readonly property bool showingSound:     view === SettingsContent.View.Sound
    readonly property bool showingBluetooth: view === SettingsContent.View.Bluetooth
    readonly property bool showingPower:     view === SettingsContent.View.Power
    property string passwordRowSsid: ""
    property bool showPassword: false
    property string connectError: ""

    readonly property int popupWidth: 232
    readonly property int settingsHeight: 228
    readonly property int wifiHeight: 244
    readonly property int passwordHeight: 94
    readonly property int soundHeight: 136
    readonly property int bluetoothHeight: 136
    readonly property int powerHeight: 176

    readonly property int viewWidth: popupWidth
    readonly property int viewHeight: {
        if (showingWifi) return passwordRowSsid !== "" ? passwordHeight : wifiHeight
        if (showingSound) return soundHeight
        if (showingBluetooth) return bluetoothHeight
        if (showingPower) return powerHeight
        return settingsHeight
    }

    readonly property bool _batteryReady: battery && battery.ready && battery.isPresent
    readonly property int _batteryPercent: {
        if (!_batteryReady) return 0
        if (battery.state === UPowerDeviceState.FullyCharged) return 100
        return Math.round(battery.percentage * 100)
    }
    readonly property bool _isCharging: _batteryReady &&
        (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)
    readonly property string _batteryTimeText: {
        if (!_batteryReady) return ""
        if (battery.state === UPowerDeviceState.FullyCharged) return "Full"
        let seconds = 0
        if (battery.state === UPowerDeviceState.Charging) seconds = battery.timeToFull
        else if (battery.state === UPowerDeviceState.Discharging) seconds = battery.timeToEmpty
        if (!seconds || seconds <= 0) return ""
        const hrs = Math.floor(seconds / 3600)
        const mins = Math.floor((seconds % 3600) / 60)
        if (hrs > 0) return hrs + "hr " + mins + "m"
        return mins + "m"
    }

    Process {
        id: setSinkProc
        running: false
        property string _stderr: ""
        stderr: StdioCollector { onStreamFinished: setSinkProc._stderr = text }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[settings] wpctl set-default failed (exit",
                    code + "):", setSinkProc._stderr.trim() || "(no stderr)")
            }
        }
    }

    Connections {
        target: root.net
        function onConnectResult(ssid, ok, error) {
            if (!ok && root.showingWifi) {
                root.passwordRowSsid = ssid
                root.connectError = error
            }
        }
    }

    Item {
        id: settingsView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.settingsHeight
        opacity: (root.showingWifi || root.showingSound || root.showingBluetooth || root.showingPower) ? 0.0 : 1.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Item {
            id: headerRow
            x: 16; y: 15
            width: 200; height: 26

            // Power button (left)
            PowerIcon {
                id: headerPowerIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                opacity: headerPowerMouse.containsMouse ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            MouseArea {
                id: headerPowerMouse
                anchors.fill: headerPowerIcon
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.view = SettingsContent.View.Power
            }

            // Battery section. The hover area is sized to the FULL row width
            // (battery + percent + time) so hovering doesn't shrink the area
            // and oscillate, but its x position animates: when unhovered, only
            // battery+percent are centered in the header; on hover, the whole
            // row centers, so the battery slides left and the time text fades
            // in on the right.
            MouseArea {
                id: batteryHoverArea
                readonly property real _mainWidth: 20 + batteryRow.spacing + percentText.implicitWidth
                readonly property real _hoveredX: (parent.width - width) / 2
                readonly property real _unhoveredX: parent.width / 2 - 4 - _mainWidth / 2
                x: containsMouse ? _hoveredX : _unhoveredX
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                anchors.verticalCenter: parent.verticalCenter
                width: batteryRow.implicitWidth + 8
                height: 20
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                Row {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: 2

                    BatteryIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        percent: root._batteryPercent
                        isCharging: root._isCharging
                    }

                    Text {
                        id: percentText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._batteryPercent + "%"
                        color: Qt.rgba(1, 1, 1, 0.8)
                        font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
                        font.letterSpacing: -0.12
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._batteryTimeText !== "" ? " (" + root._batteryTimeText + ")" : ""
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Normal
                        font.letterSpacing: -0.12
                        visible: root._batteryTimeText !== ""
                        opacity: batteryHoverArea.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            // Lock button (right)
            LockIcon {
                id: headerLockIcon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: headerLockMouse.containsMouse ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            MouseArea {
                id: headerLockMouse
                anchors.fill: headerLockIcon
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("exec hyprlock")
            }
        }

        Rectangle {
            x: 16; y: 52; width: 94; height: 92; radius: 12
            color: Qt.rgba(0.792, 0.867, 1.0, wifiCardMouse.containsMouse ? 0.25 : 0.15)
            Behavior on color { ColorAnimation { duration: 150 } }

            WifiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                signalLevel: root.net.signalLevel(root.net.connectedSignal)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: root.net.connectedSsid || "Wifi"
                color: Qt.rgba(1, 1, 1, 0.8)
                font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
                elide: Text.ElideRight
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                id: wifiCardMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { root.view = SettingsContent.View.Wifi; wifiView._rebuildModel(); root.net.scan() }
            }
        }

        Rectangle {
            x: 122; y: 52; width: 94; height: 92; radius: 12
            color: Qt.rgba(0.792, 0.867, 1.0, btCardMouse.containsMouse ? 0.25 : 0.15)
            Behavior on color { ColorAnimation { duration: 150 } }

            Shape {
                width: 20; height: 20
                anchors.horizontalCenter: parent.horizontalCenter
                y: 22
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 10; y1: -20; x2: 10; y2: 38
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                    }
                    PathSvg { path: "M9.1665 18.3332V11.9998L5.33317 15.8332L4.1665 14.6665L8.83317 9.99984L4.1665 5.33317L5.33317 4.1665L9.1665 7.99984V1.6665H9.99984L14.7498 6.4165L11.1665 9.99984L14.7498 13.5832L9.99984 18.3332H9.1665ZM10.8332 7.99984L12.4165 6.4165L10.8332 4.87484V7.99984ZM10.8332 15.1248L12.4165 13.5832L10.8332 11.9998V15.1248Z" }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: "Bluetooth"
                color: Qt.rgba(1, 1, 1, 0.8)
                font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
            }

            MouseArea {
                id: btCardMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.view = SettingsContent.View.Bluetooth
            }
        }

        Rectangle {
            id: volumeCard
            x: 16; y: 154; width: 200; height: 60; radius: 12
            color: Qt.rgba(0.792, 0.867, 1.0, soundCardMouse.containsMouse ? 0.25 : 0.15)
            Behavior on color { ColorAnimation { duration: 150 } }

            readonly property real currentVolume: root.sink?.audio?.volume ?? 0

            Text {
                x: 10; y: 8; text: "Sound"
                color: Qt.rgba(1, 1, 1, 0.8)
                font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
            }

            Text {
                anchors.right: soundChevron.left
                anchors.rightMargin: 4
                y: 8
                text: root.sink?.description ?? "Speaker"
                color: Qt.rgba(1, 1, 1, 0.5)
                font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
                elide: Text.ElideRight
                width: 60
                horizontalAlignment: Text.AlignRight
            }

            // Right-pointing chevron
            Shape {
                id: soundChevron
                x: 184; y: 12
                width: 6; height: 8
                opacity: 0.5
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 3; y1: -6; x2: 3; y2: 16
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                    }
                    PathSvg { path: "M0.393 0.393C0.783 0.002 1.416 0.002 1.807 0.393L4.807 3.393C5.197 3.783 5.197 4.416 4.807 4.807L1.807 7.807C1.416 8.197 0.783 8.197 0.393 7.807C0.002 7.416 0.002 6.783 0.393 6.393L2.686 4.1L0.393 1.807C0.002 1.416 0.002 0.783 0.393 0.393Z" }
                }
            }

            MouseArea {
                id: soundCardMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.view = SettingsContent.View.Sound
            }

            Shape {
                x: 10; y: 33; width: 9; height: 14
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 4.5; y1: -18; x2: 4.5; y2: 30
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                    }
                    PathSvg { path: "M1.5 10H3L7.19063 13.725C7.39063 13.9031 7.64688 14 7.9125 14C8.5125 14 9 13.5125 9 12.9125V1.0875C9 0.4875 8.5125 0 7.9125 0C7.64688 0 7.39063 0.0968751 7.19063 0.275L3 4H1.5C0.671875 4 0 4.67187 0 5.5V8.5C0 9.32812 0.671875 10 1.5 10Z" }
                }
            }

            Item {
                id: sliderArea
                x: 26; y: 33; width: 141; height: 14

                Rectangle {
                    id: trackBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Qt.rgba(0.859, 0.839, 0.792, 0.3)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(6, trackBg.width * Math.min(1.0, volumeCard.currentVolume))
                    height: 6; radius: 3
                    color: Qt.rgba(0.859, 0.839, 0.792, 1.0)
                    Behavior on width { NumberAnimation { duration: 50 } }
                }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    onPressed: (mouse) => setVol(mouse)
                    onPositionChanged: (mouse) => { if (pressed) setVol(mouse) }
                    function setVol(mouse) {
                        const v = Math.max(0, Math.min(1, (mouse.x + 4) / sliderArea.width))
                        if (root.sink?.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v }
                    }
                }
            }

            Shape {
                x: 174; y: 33; width: 16; height: 14
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 8; y1: -18; x2: 8; y2: 30
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                    }
                    PathSvg { path: "M1.5 10H3L7.19063 13.725C7.39062 13.9031 7.64688 14 7.9125 14C8.5125 14 9 13.5125 9 12.9125V1.0875C9 0.4875 8.5125 0 7.9125 0C7.64688 0 7.39062 0.0968751 7.19063 0.275L3 4H1.5C0.671875 4 0 4.67187 0 5.5V8.5C0 9.32812 0.671875 10 1.5 10Z" }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 8; y1: -18; x2: 8; y2: 30
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                    }
                    PathSvg { path: "M13.7844 2.34375C13.4625 2.08125 12.9906 2.13125 12.7281 2.45312C12.4656 2.775 12.5156 3.24687 12.8375 3.50937C13.8531 4.33437 14.5 5.59062 14.5 7C14.5 8.40937 13.8531 9.66562 12.8375 10.4937C12.5156 10.7562 12.4688 11.2281 12.7281 11.55C12.9875 11.8719 13.4625 11.9187 13.7844 11.6594C15.1344 10.5594 16 8.88125 16 7.00312C16 5.125 15.1344 3.44687 13.7844 2.34687V2.34375Z" }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 8; y1: -18; x2: 8; y2: 30
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                    }
                    PathSvg { path: "M11.8938 4.67187C11.5719 4.40937 11.1 4.45937 10.8375 4.78125C10.575 5.10312 10.625 5.575 10.9469 5.8375C11.2844 6.1125 11.5 6.53125 11.5 7C11.5 7.46875 11.2844 7.8875 10.9469 8.16562C10.625 8.42812 10.5781 8.9 10.8375 9.22187C11.0969 9.54375 11.5719 9.59062 11.8938 9.33125C12.5656 8.77812 13 7.94062 13 7C13 6.05937 12.5656 5.22187 11.8906 4.67187H11.8938Z" }
                }
            }
        }
    } // settingsView

    Item {
        id: wifiView
        anchors.fill: parent
        clip: true
        opacity: root.showingWifi && root.passwordRowSsid === "" ? 1.0 : 0.0
        visible: opacity > 0 && root.passwordRowSsid === ""
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Rectangle {
            id: backButton
            x: 16; y: 12; width: 26; height: 26; radius: 13
            color: Qt.rgba(0.792, 0.867, 1.0, backMouse.containsMouse ? 0.20 : 0.10)
            Behavior on color { ColorAnimation { duration: 150 } }

            Shape {
                anchors.centerIn: parent
                width: 6; height: 10
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.8)
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M5 9L1 5L5 1" }
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { root.passwordRowSsid = ""; root.view = SettingsContent.View.Settings }
            }
        }

        Text {
            x: 51
            anchors.verticalCenter: backButton.verticalCenter
            text: "Wifi"
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: "Geist"; font.pixelSize: 15; font.weight: Font.Medium
        }

        Rectangle {
            x: 184; y: 16; width: 32; height: 18; radius: 9
            color: Qt.rgba(0.792, 0.867, 1.0, 0.30)

            Rectangle {
                width: 14; height: 14; radius: 7; color: "white"
                anchors.verticalCenter: parent.verticalCenter
                x: root.net.wifiEnabled ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.net.setWifiEnabled(!root.net.wifiEnabled)
            }
        }

        Rectangle { x: 16; y: 49; width: 200; height: 1; color: Qt.rgba(0.792, 0.867, 1.0, 0.20) }

        property var _networkModel: []
        function _rebuildModel() {
            const arr = Object.values(root.net.networks)
            arr.sort((a, b) => b.signal - a.signal)
            _networkModel = arr
        }
        Connections {
            target: root.net
            function onScanFinished() { wifiView._rebuildModel() }
        }

        ListView {
            id: networkList
            x: 0; y: 56
            width: parent.width
            height: parent.height - 56 - 8
            clip: true
            spacing: 0

            model: wifiView._networkModel

            delegate: Item {
                id: row
                width: networkList.width
                height: 36

                required property var modelData
                readonly property bool isConnected: modelData.ssid === root.net.connectedSsid
                readonly property bool isHovered: rowMouse.containsMouse
                readonly property bool isPasswordRow: root.passwordRowSsid === modelData.ssid

                Rectangle {
                    id: pillBg
                    x: 10; y: 0; width: 212; height: 36; radius: 18
                    color: Qt.rgba(0.792, 0.867, 1.0, 0.10)
                    opacity: row.isConnected || row.isHovered || row.isPasswordRow ? 1 : 0
                    property bool _ready: false
                    Component.onCompleted: _ready = true
                    Behavior on opacity {
                        enabled: pillBg._ready
                        NumberAnimation { duration: 150 }
                    }
                }

                WifiIcon {
                    id: rowIcon
                    x: 17
                    anchors.verticalCenter: parent.verticalCenter
                    signalLevel: root.net.signalLevel(row.modelData.signal)
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.right: parent.right
                    anchors.rightMargin: 48
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.ssid
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                // Hover + row click handler
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: row.isConnected ? Qt.NoButton : Qt.LeftButton
                    onClicked: {
                        if (row.modelData.saved || !row.modelData.secured) {
                            root.net.connect(row.modelData.ssid, "")
                        } else {
                            root.passwordRowSsid = row.modelData.ssid
                        }
                    }
                }

                // Lock icon (secured, not connected, not password mode, hidden when connect icon shows)
                Shape {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    preferredRendererType: Shape.CurveRenderer
                    visible: !row.isConnected && row.modelData.secured && !row.isPasswordRow && !(row.modelData.saved && row.isHovered)

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 6; y1: -5; x2: 6; y2: 17
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        PathSvg { path: "M3 11C2.725 11 2.49 10.902 2.294 10.707C2.098 10.511 2 10.275 2 10V5C2 4.725 2.098 4.49 2.294 4.294C2.49 4.098 2.725 4 3 4H3.5V3C3.5 2.308 3.744 1.719 4.232 1.232C4.719 0.744 5.309 0.5 6 0.5C6.691 0.5 7.281 0.744 7.769 1.232C8.257 1.72 8.501 2.309 8.5 3V4H9C9.275 4 9.51 4.098 9.707 4.294C9.903 4.49 10 4.725 10 5V10C10 10.275 9.902 10.51 9.707 10.707C9.511 10.903 9.275 11 9 11H3ZM6.707 8.207C6.902 8.011 7 7.775 7 7.5C7 7.225 6.902 6.99 6.707 6.794C6.511 6.598 6.275 6.5 6 6.5C5.725 6.5 5.489 6.598 5.294 6.794C5.099 6.99 5.001 7.226 5 7.5C4.999 7.774 5.097 8.01 5.294 8.207C5.491 8.403 5.726 8.501 6 8.5C6.274 8.499 6.51 8.401 6.707 8.207ZM4.5 4H7.5V3C7.5 2.583 7.354 2.229 7.062 1.938C6.771 1.646 6.417 1.5 6 1.5C5.583 1.5 5.229 1.646 4.938 1.938C4.646 2.229 4.5 2.583 4.5 3V4Z" }
                    }
                }

                // Connect icon (saved/known networks only, on hover, replaces lock)
                Shape {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    preferredRendererType: Shape.CurveRenderer
                    visible: !row.isConnected && !row.isPasswordRow && row.isHovered && row.modelData.saved

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 8; y1: -3.4; x2: 8; y2: 18.6
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        PathSvg { path: "M0.799805 7.99944C0.799871 7.15087 1.1523 6.33731 1.77914 5.73727C2.40598 5.13723 3.25588 4.79987 4.14235 4.7998H6.07089C6.49693 4.7998 6.84231 5.13041 6.84231 5.53824C6.84231 5.94606 6.49693 6.27667 6.07089 6.27667H4.14235C3.66506 6.27674 3.20747 6.45839 2.86997 6.78146C2.53247 7.10453 2.3427 7.54256 2.34263 7.99944C2.34263 8.45642 2.53241 8.89502 2.86997 9.21815C3.20746 9.54114 3.66512 9.72287 4.14235 9.72294H6.07089C6.49693 9.72294 6.84231 10.0535 6.84231 10.4614C6.84217 10.8691 6.49685 11.1998 6.07089 11.1998H4.14235C3.25594 11.1997 2.40597 10.8623 1.77914 10.2623C1.15224 9.66225 0.799805 8.8481 0.799805 7.99944ZM13.657 7.99944C13.6569 7.54262 13.4671 7.10452 13.1296 6.78146C12.7921 6.45833 12.3339 6.27667 11.8565 6.27667H9.92797C9.50204 6.27654 9.15655 5.94598 9.15655 5.53824C9.15655 5.13049 9.50204 4.79993 9.92797 4.7998H11.8565C12.7431 4.7998 13.5936 5.13718 14.2205 5.73727C14.8472 6.33729 15.1997 7.15093 15.1998 7.99944C15.1998 8.8481 14.8474 9.66225 14.2205 10.2623C13.5936 10.8624 12.7431 11.1998 11.8565 11.1998H9.92797C9.50212 11.1997 9.15669 10.869 9.15655 10.4614C9.15655 10.0536 9.50204 9.72307 9.92797 9.72294H11.8565C12.3339 9.72294 12.7921 9.54128 13.1296 9.21815C13.4672 8.89502 13.657 8.45641 13.657 7.99944ZM10.5713 7.26101C10.9972 7.26114 11.3426 7.59181 11.3427 7.99944C11.3427 8.40719 10.9972 8.73775 10.5713 8.73788H5.4283C5.00225 8.73788 4.65688 8.40727 4.65688 7.99944C4.65702 7.59173 5.00234 7.26101 5.4283 7.26101H10.5713Z" }
                    }
                }

                // Disconnect button (connected only, declared last for z-order)
                Item {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    visible: row.isConnected

                    Rectangle {
                        anchors.fill: parent; radius: 13
                        color: Qt.rgba(0.792, 0.867, 1.0, disconnectMouse.containsMouse ? 0.35 : 0.20)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 13; y1: 1.5; x2: 13; y2: 23.6
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                            }
                            PathSvg { path: "M5.7998 12.9994C5.79987 12.1509 6.1523 11.3373 6.77914 10.7373C7.40598 10.1372 8.25588 9.79987 9.14235 9.7998H9.72859C10.1546 9.7998 10.5 10.1304 10.5 10.5382C10.5 10.9461 10.1546 11.2767 9.72859 11.2767H9.14235C8.66506 11.2767 8.20747 11.4584 7.86997 11.7815C7.53247 12.1045 7.3427 12.5426 7.34263 12.9994C7.34263 13.4564 7.53241 13.895 7.86997 14.2181C8.20746 14.5411 8.66512 14.7229 9.14235 14.7229H11.0709C11.4969 14.7229 11.8423 15.0535 11.8423 15.4614C11.8422 15.8691 11.4968 16.1998 11.0709 16.1998H9.14235C8.25594 16.1997 7.40597 15.8623 6.77914 15.2623C6.15224 14.6622 5.7998 13.8481 5.7998 12.9994Z" }
                        }

                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 13; y1: 1.5; x2: 13; y2: 23.6
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                            }
                            PathSvg { path: "M18.657 12.9994C18.6569 12.5426 18.4671 12.1045 18.1296 11.7815C17.7921 11.4583 17.3339 11.2767 16.8565 11.2767H14.928C14.502 11.2765 14.1566 10.946 14.1566 10.5382C14.1566 10.1305 14.502 9.79993 14.928 9.7998H16.8565C17.7431 9.7998 18.5936 10.1372 19.2205 10.7373C19.8472 11.3373 20.1997 12.1509 20.1998 12.9994C20.1998 13.8481 19.8474 14.6622 19.2205 15.2623C18.5936 15.8624 17.7431 16.1998 16.8565 16.1998H16.7714C16.3456 16.1997 16.0001 15.869 16 15.4614C16 15.0536 16.3455 14.7231 16.7714 14.7229H16.8565C17.3339 14.7229 17.7921 14.5413 18.1296 14.2181C18.4672 13.895 18.657 13.4564 18.657 12.9994Z" }
                        }
                    }

                    // Diagonal slash
                    Rectangle {
                        x: 10.189; y: 8.965
                        width: 2; height: 10.054; radius: 1
                        transformOrigin: Item.TopLeft
                        rotation: -26.8175
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                    }

                    MouseArea {
                        id: disconnectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.net.disconnect(row.modelData.ssid)
                    }
                }
            } // delegate
        } // ListView
    } // wifiView

    Item {
        id: passwordView
        anchors.fill: parent
        opacity: root.showingWifi && root.passwordRowSsid !== "" ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        readonly property var pwNet: root.passwordRowSsid !== "" ? root.net.networks[root.passwordRowSsid] ?? null : null

        Rectangle {
            id: pwBackButton
            x: 12; y: 12; width: 26; height: 26; radius: 13
            color: Qt.rgba(0.792, 0.867, 1.0, pwBackMouse.containsMouse ? 0.20 : 0.10)
            Behavior on color { ColorAnimation { duration: 150 } }

            Shape {
                anchors.centerIn: parent
                width: 6; height: 10
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.8)
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M5 9L1 5L5 1" }
                }
            }

            MouseArea {
                id: pwBackMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { root.passwordRowSsid = ""; root.showPassword = false }
            }
        }

        Text {
            x: 44
            anchors.verticalCenter: pwBackButton.verticalCenter
            text: root.passwordRowSsid
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: "Geist"; font.pixelSize: 15; font.weight: Font.Medium
        }

        WifiIcon {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: pwBackButton.verticalCenter
            signalLevel: passwordView.pwNet ? root.net.signalLevel(passwordView.pwNet.signal) : 0
        }

        Rectangle {
            x: 10; y: 46
            width: 212; height: 36; radius: 18
            color: Qt.rgba(0.792, 0.867, 1.0, 0.20)

            TextField {
                id: pwField
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 36
                verticalAlignment: TextInput.AlignVCenter
                echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                passwordCharacter: "\u25CF"
                color: "white"
                font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: -0.15
                placeholderText: root.connectError !== "" ? root.connectError : "Type password"
                placeholderTextColor: root.connectError !== "" ? Qt.rgba(1, 0.5, 0.4, 0.6) : Qt.rgba(1, 1, 1, 0.5)
                background: null
                selectByMouse: true

                onVisibleChanged: { if (visible) { text = ""; root.connectError = ""; forceActiveFocus() } }

                onAccepted: {
                    if (text.length === 0) return
                    root.net.connect(root.passwordRowSsid, text)
                    text = ""
                    root.passwordRowSsid = ""
                    root.showPassword = false
                }

                Keys.onEscapePressed: {
                    text = ""
                    root.passwordRowSsid = ""
                    root.showPassword = false
                }
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16

                // Hidden eye (default)
                Shape {
                    anchors.centerIn: parent
                    width: 11; height: 5
                    preferredRendererType: Shape.CurveRenderer
                    visible: !root.showPassword
                    ShapePath {
                        strokeColor: "white"
                        strokeWidth: 1
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: "M0.5 0.5C0.5 0.5 2.25 2.5 5.5 2.5C8.75 2.5 10.5 0.5 10.5 0.5M1.5 1.3225L0.5 2.5M10.5 2.5L9.502 1.324M3.957 2.34L3.5 3.75M7.0315 2.344L7.5 3.75" }
                    }
                }

                // Open eye (showing)
                Shape {
                    anchors.centerIn: parent
                    width: 13; height: 13
                    preferredRendererType: Shape.CurveRenderer
                    visible: root.showPassword
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 6.5; y1: -4; x2: 6.5; y2: 12.3
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        PathSvg { path: "M0.941277 5.73422C3.15661 0.81125 9.84313 0.81125 12.0585 5.73422C12.2284 6.11195 12.0602 6.55545 11.6825 6.72543C11.3048 6.89541 10.8613 6.72718 10.6913 6.34945C9.00661 2.60575 3.99313 2.60575 2.30846 6.34945C2.13849 6.72718 1.69498 6.89541 1.31725 6.72543C0.939523 6.55545 0.771299 6.11195 0.941277 5.73422Z" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 6.5; y1: -0.9; x2: 6.5; y2: 15.5
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        PathSvg { path: "M6.5 5.20801C7.12989 5.20801 7.73429 5.4589 8.17969 5.9043C8.62493 6.34967 8.875 6.95421 8.875 7.58398C8.87487 8.2137 8.62497 8.81839 8.17969 9.26367C7.73431 9.70892 7.12977 9.95898 6.5 9.95898C6.18817 9.95898 5.87892 9.89763 5.59082 9.77832C5.30287 9.65901 5.04075 9.48404 4.82031 9.26367C4.59994 9.04329 4.42501 8.78106 4.30566 8.49316C4.18637 8.20517 4.12506 7.89571 4.125 7.58398C4.125 7.27225 4.18642 6.96283 4.30566 6.6748C4.42497 6.38685 4.59994 6.12473 4.82031 5.9043C5.04075 5.68386 5.30283 5.509 5.59082 5.38965C5.87897 5.27029 6.18811 5.20801 6.5 5.20801Z" }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: root.showPassword = !root.showPassword
                }
            }
        }
    } // passwordView

    Item {
        id: soundView
        anchors.fill: parent
        clip: true
        opacity: root.showingSound ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        Rectangle {
            id: soundBackBtn
            x: 16; y: 12; width: 26; height: 26; radius: 13
            color: Qt.rgba(0.792, 0.867, 1.0, soundBackMouse.containsMouse ? 0.20 : 0.10)
            Behavior on color { ColorAnimation { duration: 150 } }

            Shape {
                anchors.centerIn: parent
                width: 6; height: 10
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.8)
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M5 9L1 5L5 1" }
                }
            }

            MouseArea {
                id: soundBackMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.view = SettingsContent.View.Settings
            }
        }

        Text {
            x: 51
            anchors.verticalCenter: soundBackBtn.verticalCenter
            text: "Sound output"
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: "Geist"; font.pixelSize: 15; font.weight: Font.Medium
        }

        Rectangle {
            id: soundDivider
            x: 16; y: 49; width: 200; height: 1
            color: Qt.rgba(0.792, 0.867, 1.0, 0.2)
        }

        ListView {
            id: sinkList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: soundDivider.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            clip: true
            spacing: 0

            model: {
                const sinks = []
                if (!Pipewire.nodes) return sinks
                for (let i = 0; i < Pipewire.nodes.values.length; i++) {
                    const n = Pipewire.nodes.values[i]
                    if (n && n.isSink && !n.isStream) sinks.push(n)
                }
                return sinks
            }

            delegate: Item {
                width: sinkList.width
                height: 36

                required property var modelData
                property bool isDefault: modelData.id === (Pipewire.defaultAudioSink?.id ?? -1)
                property bool isHovered: sinkRowMouse.containsMouse

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    radius: 18
                    color: Qt.rgba(0.792, 0.867, 1.0, 0.1)
                    opacity: isDefault || isHovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Device icon (speaker)
                Shape {
                    id: sinkIcon
                    x: 20; width: 12; height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 6; y1: -12; x2: 6; y2: 30
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        PathSvg { path: "M10.1665 16.3334H1.83317C1.37484 16.3334 0.982614 16.1704 0.656503 15.8442C0.330392 15.5181 0.167114 15.1256 0.166504 14.6667V1.33337C0.166504 0.875042 0.329782 0.482819 0.656504 0.156708C0.983225 -0.169402 1.37545 -0.332681 1.83317 -0.333292H10.1665C10.6248 -0.333292 11.0173 -0.170014 11.344 0.156708C11.6707 0.48343 11.8337 0.875653 11.8332 1.33337V14.6667C11.8332 15.1251 11.6701 15.5176 11.344 15.8442C11.0179 16.1709 10.6254 16.334 10.1665 16.3334ZM7.17734 5.01087C7.50345 4.68415 7.6665 4.29171 7.6665 3.83337C7.6665 3.37504 7.50345 2.98282 7.17734 2.65671C6.85123 2.33059 6.4588 2.16731 5.99984 2.16671C5.54089 2.16609 5.14867 2.32937 4.82317 2.65671C4.49767 2.98404 4.33434 3.37626 4.33317 3.83337C4.332 4.29049 4.49534 4.68293 4.82317 5.01087C5.15101 5.33882 5.54323 5.50171 5.99984 5.50004C6.45645 5.49837 6.84889 5.33537 7.17734 5.01087ZM8.354 12.8542C9.00678 12.2015 9.33317 11.4167 9.33317 10.5001C9.33317 9.58337 9.00678 8.79865 8.354 8.14587C7.70123 7.4931 6.9165 7.16671 5.99984 7.16671C5.08317 7.16671 4.29845 7.4931 3.64567 8.14587C2.99289 8.79865 2.6665 9.58337 2.6665 10.5001C2.6665 11.4167 2.99289 12.2015 3.64567 12.8542C4.29845 13.507 5.08317 13.8334 5.99984 13.8334C6.9165 13.8334 7.70123 13.507 8.354 12.8542Z" }
                    }
                }

                // Device name
                Text {
                    anchors.left: sinkIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.description || modelData.nickname || modelData.name || "Unknown"
                    color: Qt.rgba(1, 1, 1, 0.8)
                    font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Shape {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 10
                    visible: isDefault
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 7; y1: -13; x2: 7; y2: 21
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        PathSvg { path: "M11.8573 0.292893C12.2478 -0.0976311 12.8808 -0.0976311 13.2713 0.292893C13.6619 0.683417 13.6619 1.31643 13.2713 1.70696L5.32115 9.65715C4.93063 10.0477 4.29761 10.0477 3.90709 9.65715L0.292832 6.04387C-0.0976514 5.65339 -0.09757 5.02034 0.292832 4.62981C0.683356 4.23928 1.31637 4.23928 1.70689 4.62981L4.61314 7.53606L11.8573 0.292893Z" }
                    }
                }

                MouseArea {
                    id: sinkRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (!isDefault) {
                            setSinkProc.command = ["wpctl", "set-default", modelData.id.toString()]
                            setSinkProc.running = true
                        }
                    }
                }
            }
        }
    } // soundView

    Item {
        id: bluetoothView
        anchors.fill: parent
        clip: true
        visible: root.showingBluetooth

        Rectangle {
            id: btBackButton
            x: 16; y: 12; width: 26; height: 26; radius: 13
            color: Qt.rgba(0.792, 0.867, 1.0, btBackMouse.containsMouse ? 0.20 : 0.10)

            Shape {
                anchors.centerIn: parent
                width: 6; height: 10
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.8)
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M5 9L1 5L5 1" }
                }
            }

            MouseArea {
                id: btBackMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.view = SettingsContent.View.Settings
            }
        }

        Text {
            x: 51
            anchors.verticalCenter: btBackButton.verticalCenter
            text: "Bluetooth"
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: "Geist"; font.pixelSize: 15; font.weight: Font.Medium
        }

        Rectangle {
            x: 184; y: 16; width: 32; height: 18; radius: 9
            color: Qt.rgba(0.792, 0.867, 1.0, 0.30)

            Rectangle {
                width: 14; height: 14; radius: 7; color: "white"
                anchors.verticalCenter: parent.verticalCenter
                x: Bluetooth.defaultAdapter?.enabled ? parent.width - width - 2 : 2
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (Bluetooth.defaultAdapter)
                        Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                }
            }
        }

        Rectangle { x: 16; y: 49; width: 200; height: 1; color: Qt.rgba(0.792, 0.867, 1.0, 0.20) }

        ListView {
            id: btDeviceList
            x: 0; y: 56
            width: parent.width
            height: parent.height - 56 - 8
            clip: true
            spacing: 0

            model: Bluetooth.devices

            delegate: Item {
                id: btRow
                width: btDeviceList.width
                height: 36

                required property var modelData
                readonly property bool isConnected: modelData.connected

                Rectangle {
                    x: 10; y: 0; width: 212; height: 36; radius: 18
                    color: Qt.rgba(0.792, 0.867, 1.0, 0.10)
                    visible: btRow.isConnected || btRowMouse.containsMouse
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 48
                    anchors.verticalCenter: parent.verticalCenter
                    text: btRow.modelData.name || btRow.modelData.address
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: btRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                // Connect button (not connected)
                Item {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    visible: !btRow.isConnected

                    Rectangle {
                        anchors.fill: parent; radius: 13
                        color: Qt.rgba(0.792, 0.867, 1.0, btConnectMouse.containsMouse ? 0.35 : 0.20)
                    }

                    Shape {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 8; y1: -3.4; x2: 8; y2: 18.6
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                            }
                            PathSvg { path: "M0.799805 7.99944C0.799871 7.15087 1.1523 6.33731 1.77914 5.73727C2.40598 5.13723 3.25588 4.79987 4.14235 4.7998H6.07089C6.49693 4.7998 6.84231 5.13041 6.84231 5.53824C6.84231 5.94606 6.49693 6.27667 6.07089 6.27667H4.14235C3.66506 6.27674 3.20747 6.45839 2.86997 6.78146C2.53247 7.10453 2.3427 7.54256 2.34263 7.99944C2.34263 8.45642 2.53241 8.89502 2.86997 9.21815C3.20746 9.54114 3.66512 9.72287 4.14235 9.72294H6.07089C6.49693 9.72294 6.84231 10.0535 6.84231 10.4614C6.84217 10.8691 6.49685 11.1998 6.07089 11.1998H4.14235C3.25594 11.1997 2.40597 10.8623 1.77914 10.2623C1.15224 9.66225 0.799805 8.8481 0.799805 7.99944ZM13.657 7.99944C13.6569 7.54262 13.4671 7.10452 13.1296 6.78146C12.7921 6.45833 12.3339 6.27667 11.8565 6.27667H9.92797C9.50204 6.27654 9.15655 5.94598 9.15655 5.53824C9.15655 5.13049 9.50204 4.79993 9.92797 4.7998H11.8565C12.7431 4.7998 13.5936 5.13718 14.2205 5.73727C14.8472 6.33729 15.1997 7.15093 15.1998 7.99944C15.1998 8.8481 14.8474 9.66225 14.2205 10.2623C13.5936 10.8624 12.7431 11.1998 11.8565 11.1998H9.92797C9.50212 11.1997 9.15669 10.869 9.15655 10.4614C9.15655 10.0536 9.50204 9.72307 9.92797 9.72294H11.8565C12.3339 9.72294 12.7921 9.54128 13.1296 9.21815C13.4672 8.89502 13.657 8.45641 13.657 7.99944ZM10.5713 7.26101C10.9972 7.26114 11.3426 7.59181 11.3427 7.99944C11.3427 8.40719 10.9972 8.73775 10.5713 8.73788H5.4283C5.00225 8.73788 4.65688 8.40727 4.65688 7.99944C4.65702 7.59173 5.00234 7.26101 5.4283 7.26101H10.5713Z" }
                        }
                    }

                    MouseArea {
                        id: btConnectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: btRow.modelData.connect()
                    }
                }

                // Disconnect button (connected)
                Item {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    visible: btRow.isConnected

                    Rectangle {
                        anchors.fill: parent; radius: 13
                        color: Qt.rgba(0.792, 0.867, 1.0, btDisconnectMouse.containsMouse ? 0.35 : 0.20)
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 13; y1: 1.5; x2: 13; y2: 23.6
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                            }
                            PathSvg { path: "M5.7998 12.9994C5.79987 12.1509 6.1523 11.3373 6.77914 10.7373C7.40598 10.1372 8.25588 9.79987 9.14235 9.7998H9.72859C10.1546 9.7998 10.5 10.1304 10.5 10.5382C10.5 10.9461 10.1546 11.2767 9.72859 11.2767H9.14235C8.66506 11.2767 8.20747 11.4584 7.86997 11.7815C7.53247 12.1045 7.3427 12.5426 7.34263 12.9994C7.34263 13.4564 7.53241 13.895 7.86997 14.2181C8.20746 14.5411 8.66512 14.7229 9.14235 14.7229H11.0709C11.4969 14.7229 11.8423 15.0535 11.8423 15.4614C11.8422 15.8691 11.4968 16.1998 11.0709 16.1998H9.14235C8.25594 16.1997 7.40597 15.8623 6.77914 15.2623C6.15224 14.6622 5.7998 13.8481 5.7998 12.9994Z" }
                        }
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 13; y1: 1.5; x2: 13; y2: 23.6
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                            }
                            PathSvg { path: "M18.657 12.9994C18.6569 12.5426 18.4671 12.1045 18.1296 11.7815C17.7921 11.4583 17.3339 11.2767 16.8565 11.2767H14.928C14.502 11.2765 14.1566 10.946 14.1566 10.5382C14.1566 10.1305 14.502 9.79993 14.928 9.7998H16.8565C17.7431 9.7998 18.5936 10.1372 19.2205 10.7373C19.8472 11.3373 20.1997 12.1509 20.1998 12.9994C20.1998 13.8481 19.8474 14.6622 19.2205 15.2623C18.5936 15.8624 17.7431 16.1998 16.8565 16.1998H16.7714C16.3456 16.1997 16.0001 15.869 16 15.4614C16 15.0536 16.3455 14.7231 16.7714 14.7229H16.8565C17.3339 14.7229 17.7921 14.5413 18.1296 14.2181C18.4672 13.895 18.657 13.4564 18.657 12.9994Z" }
                        }
                    }

                    Rectangle {
                        x: 10.189; y: 8.965
                        width: 2; height: 10.054; radius: 1
                        transformOrigin: Item.TopLeft
                        rotation: -26.8175
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                    }

                    MouseArea {
                        id: btDisconnectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: btRow.modelData.disconnect()
                    }
                }
            } // delegate
        } // ListView
    } // bluetoothView

    Item {
        id: powerView
        anchors.fill: parent
        visible: root.showingPower

        Rectangle {
            id: powerBackBtn
            x: 16; y: 12; width: 26; height: 26; radius: 13
            color: Qt.rgba(0.792, 0.867, 1.0, powerBackMouse.containsMouse ? 0.20 : 0.10)
            Behavior on color { ColorAnimation { duration: 150 } }

            ChevronLeftIcon { anchors.centerIn: parent }

            MouseArea {
                id: powerBackMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.view = SettingsContent.View.Settings
            }
        }

        Text {
            x: 51
            anchors.verticalCenter: powerBackBtn.verticalCenter
            text: "Power"
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: "Geist"; font.pixelSize: 14; font.weight: Font.DemiBold
            font.letterSpacing: -0.14
        }

        Rectangle {
            id: powerDivider
            x: 16; y: 50; width: 200; height: 1
            color: Qt.rgba(0.792, 0.867, 1.0, 0.20)
        }

        Column {
            id: powerActions
            x: 10; y: 56
            width: parent.width - 20
            spacing: 0

            component PowerRow: Rectangle {
                id: pwRow
                property alias iconSource: pwIcon.source
                property alias label: pwLabel.text
                signal activated()

                width: parent.width
                height: 36
                radius: 18
                color: Qt.rgba(0.792, 0.867, 1.0, pwRowMouse.containsMouse ? 0.10 : 0.0)
                Behavior on color { ColorAnimation { duration: 120 } }

                Image {
                    id: pwIcon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    id: pwLabel
                    anchors.left: pwIcon.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.8)
                    font.family: "Geist"; font.pixelSize: 12; font.weight: Font.Medium
                    font.letterSpacing: -0.12
                }

                MouseArea {
                    id: pwRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pwRow.activated()
                }
            }

            PowerRow {
                iconSource: Qt.resolvedUrl("sleep.svg")
                label: "Sleep"
                onActivated: {
                    Quickshell.execDetached(["systemctl", "suspend"])
                    root.view = SettingsContent.View.Settings
                }
            }
            PowerRow {
                iconSource: Qt.resolvedUrl("restart.svg")
                label: "Restart"
                onActivated: {
                    Quickshell.execDetached(["systemctl", "reboot"])
                    root.view = SettingsContent.View.Settings
                }
            }
            PowerRow {
                iconSource: Qt.resolvedUrl("power.svg")
                label: "Shut down"
                onActivated: {
                    Quickshell.execDetached(["systemctl", "poweroff"])
                    root.view = SettingsContent.View.Settings
                }
            }
        }
    }

}
