import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.VectorImage
import QtQuick.Layouts
import Quickshell.Services.UPower



ShellRoot {
    id: root
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    FileView {
        id: hostnameFile
        path: "/etc/hostname"
    }

    readonly property string hostname: hostnameFile.text().trim()

    PanelWindow {
        id: panel
        anchors.top: true
        implicitHeight: 200
        implicitWidth: 1200
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dynamic-island"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        exclusiveZone: 0

        property bool hovered:  false

        mask: Region {
            item: island
        }

        Item {
            anchors.fill: parent

            Rectangle {
                id: island
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: panel.hovered ? 1200 : 150
                height: panel.hovered ? 200 : 10
                color: "#000000"
                bottomLeftRadius: 40
                bottomRightRadius: 40

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                HoverHandler {
                    id: hoverHandler
                    onHoveredChanged: {
                        panel.hovered = hovered
                    }
                }

                Text {
                    id: mainhour
                    text: Qt.formatTime(clock.date, "hh:mm")
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: panel.hovered ? 10 : 0
                    opacity: panel.hovered ? 1: 0
                    font.weight: 600
                    color: "#ffffff"
                    font.pixelSize: panel.hovered ? 50 : 17
                    font.family: "SF Mono"

                    Behavior on font.pixelSize {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }

                    Behavior on anchors.topMargin {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }
                }
                Text {
                    text: Qt.formatTime(clock.date, "ss")
                    anchors.left: mainhour.right
                    anchors.bottom: mainhour.bottom
                    anchors.bottomMargin: 6
                    anchors.leftMargin: 8
                    font.weight: 600
                    color: "#888888"
                    font.pixelSize: 23
                    font.family: "SF Mono"
                    opacity: panel.hovered ? 1 : 0

                    Behavior on font.pixelSize {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }

                    Behavior on anchors.topMargin {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }

                    Behavior on opacity {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }
                }



                Text{
                    id: hostnametext
                    text: hostname
                    font.family: "SF Mono"
                    color: "#ffffff"
                    font.pixelSize: 17
                    font.weight: 600
                    anchors.bottom: user_icon.bottom
                    anchors.left: user_icon.right
                    opacity: panel.hovered ? 1: 0
                    anchors.margins: 16
                    anchors.bottomMargin: 0

                    Behavior on opacity {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }
                }
                VectorImage {
                    id: user_icon
                    anchors.top: island.top
                    anchors.left: island.left
                    opacity: panel.hovered ? 1: 0
                    anchors.margins: 20
                    anchors.leftMargin: 16
                    source: "user.svg"
                    width: 25
                    height: 25
                    preferredRendererType: VectorImage.CurveRenderer
                }

                Text{
                    id: date_text
                    text: Qt.formatDate(clock.date, "dd MMMM yyyy")
                    font.family: "SF Mono"
                    color: "#888888"
                    font.pixelSize: 17
                    font.weight: 600
                    anchors.bottom: user_icon.bottom
                    anchors.left: hostnametext.right
                    opacity: panel.hovered ? 1: 0
                    anchors.margins: 16
                    anchors.leftMargin: 40
                    anchors.bottomMargin: 0

                    Behavior on opacity {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }
                }

                VectorImage {
                    id: battery_icon
                    anchors.top: island.top
                    anchors.left: island.left
                    opacity: panel.hovered ? 1: 0
                    anchors.margins: 21
                    anchors.leftMargin: 370
                    source: "battery.svg"
                    width: 35
                    height: 26
                    preferredRendererType: VectorImage.CurveRenderer
                }

                VectorImage {
                    property var battery: UPower.displayDevice

                    id: charging_icon
                    anchors.top: island.top
                    anchors.left: island.left
                    opacity: panel.hovered ? 1: 0
                    anchors.margins: 27
                    anchors.leftMargin: 455
                    visible: battery.state == UPowerDeviceState.Charging
                    source: "power.svg"
                    width: 15
                    height: 15
                    preferredRendererType: VectorImage.CurveRenderer
                }

                Rectangle {
                    property var battery: UPower.displayDevice

                    anchors.top: battery_icon.top
                    anchors.left: battery_icon.left
                    opacity: panel.hovered ? 1: 0

                    anchors.topMargin: 9
                    anchors.leftMargin: 7
                    width: 15 * battery.percentage
                    height: 8
                    color: {
                        var hue = battery.percentage * 0.33
                        return Qt.hsla(hue, 0.85, 0.45, 1.0)
                    }

                    Behavior on opacity {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }
                }

                Text {
                    property var battery: UPower.displayDevice

                    anchors.verticalCenter: battery_icon.verticalCenter
                    anchors.left: battery_icon.right
                    anchors.leftMargin: 10

                    opacity: panel.hovered ? 1: 0


                    text: battery.ready
                        ? Math.round(battery.percentage * 100) + "%"
                        : "No battery"

                    color: "#ffffff"
                    font.pixelSize: 17
                    font.family: "SF Mono"
                    font.weight: 600

                    function stateText(state) {
                        switch (state) {
                            case UPowerDeviceState.Charging: return "(charging)"
                            case UPowerDeviceState.Discharging: return "(discharging)"
                            case UPowerDeviceState.FullyCharged: return "(full)"
                            case UPowerDeviceState.PendingCharge: return "(pending charge)"
                            case UPowerDeviceState.PendingDischarge: return "(pending discharge)"
                            default: return ""
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }
                }



                VolumeSlider{
                    id: volume_slider
                    anchors.left: parent.left
                    anchors.bottom: brightness_slider.bottom
                    anchors.bottomMargin: 55
                    opacity: panel.hovered ? 1: 0

                    width: 350
                    height: 40
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: panel.hovered ? 0 : 100 }
                            NumberAnimation { duration: panel.hovered ? 100 : 500; easing.type: Easing.OutCubic }
                        }
                    }
                }
                Text{
                    id: volume_value
                    anchors.left: volume_slider.left
                    anchors.verticalCenter: volume_slider.verticalCenter
                    anchors.leftMargin: 16
                    text: Math.round(volume_slider.value * 100) + "%"
                    color: "#000000"
                    font.weight: 600
                    font.family: "SF Mono"
                    font.pixelSize: 17

                    opacity: panel.hovered ? 1: 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: panel.hovered ? 0 : 100 }
                            NumberAnimation { duration: panel.hovered ? 100 : 500; easing.type: Easing.OutCubic }
                        }
                    }
                    Behavior on anchors.leftMargin {
                        NumberAnimation{duration:250;easing.type: Easing.OutCubic}
                    }
                }
                VectorImage {
                    id: volume_icon
                    anchors.left: volume_slider.left
                    anchors.verticalCenter: volume_slider.verticalCenter
                    anchors.leftMargin: 10
                    source: "speaker.svg"
                    width: 25
                    height: 25
                    preferredRendererType: VectorImage.CurveRenderer
                }




                BrightnessSlider{
                    id: brightness_slider
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    opacity: panel.hovered ? 1: 0

                    width: 350
                    height: 40
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: panel.hovered ? 0 : 100 }
                            NumberAnimation { duration: panel.hovered ? 100 : 300; easing.type: Easing.OutCubic }
                        }
                    }
                }
                Text{
                    id: brightness_value
                    anchors.left: brightness_slider.left
                    anchors.verticalCenter: brightness_slider.verticalCenter
                    anchors.leftMargin: 16
                    text: Math.round(brightness_slider.value * 100) + "%"
                    color: "#000000"
                    font.weight: 600
                    font.family: "SF Mono"
                    font.pixelSize: 17

                    opacity: panel.hovered ? 1: 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: panel.hovered ? 0 : 100 }
                            NumberAnimation { duration: panel.hovered ? 100 : 300; easing.type: Easing.OutCubic }
                        }
                    }
                    Behavior on anchors.leftMargin {
                        NumberAnimation{duration:250;easing.type: Easing.OutCubic}
                    }
                }
                VectorImage {
                    id: sun_icon
                    anchors.left: brightness_slider.left
                    anchors.verticalCenter: brightness_slider.verticalCenter
                    anchors.leftMargin: 10
                    source: "sun.svg"
                    width: 25
                    height: 25
                    preferredRendererType: VectorImage.CurveRenderer
                }


                MusicPlayer{
                    id: music_player
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    anchors.bottomMargin: 4
                    opacity: panel.hovered ? 1: 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: panel.hovered ? 0 : 100 }
                            NumberAnimation { duration: panel.hovered ? 100 : 300; easing.type: Easing.OutCubic }
                        }
                    }
                }
                ShutDownButtons{
                    id: power_buttons
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: music_player.top
                    anchors.margins: 16
                    anchors.topMargin: 10
                    opacity: panel.hovered ? 1: 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: panel.hovered ? 0 : 100 }
                            NumberAnimation { duration: panel.hovered ? 100 : 300; easing.type: Easing.OutCubic }
                        }
                    }
                }

                ColumnLayout {
                    anchors.right: parent.right
                    anchors.top: power_buttons.bottom
                    anchors.left: music_player.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    anchors.topMargin: 30
                    anchors.leftMargin: 20
                    spacing: 16

                    opacity: panel.hovered ? 1: 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: panel.hovered ? 0 : 100 }
                            NumberAnimation { duration: panel.hovered ? 100 : 300; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle{
                        id: wifi_rectangle
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        radius: 22
                        property bool hovered: false
                        color: hovered ? "#333333" : "#000000"
                        border.color: "#333333"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation {duration: 250; easing.type: Easing.OutExpo}
                        }

                        Text{
                            anchors.centerIn: parent
                            text: "Wifi"
                            color: "#ffffff"
                            font.family: "SF Mono"
                            font.weight: 600
                            font.pixelSize: 17
                        }
                        HoverHandler {
                            id: hover_wifi
                            onHoveredChanged: wifi_rectangle.hovered = hover_wifi.hovered
                        }
                        TapHandler{
                            onTapped: {
                                wifi_panel.implicitWidth === 0 ? wifi_panel.implicitWidth = 350 : wifi_panel.implicitWidth = 0
                                WifiService.scanning ? WifiService.stopScan() : WifiService.scan()
                            }
                        }
                        Behavior on color {
                            ColorAnimation{duration:250;easing.type: Easing.OutCubic}
                        }
                    }

                    Rectangle{
                        id: bluetooth_rectangle
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        radius: 22
                        property bool hovered: false
                        color: hovered ? "#333333" : "#000000"
                        border.color: "#333333"
                        border.width: 1

                        Text{
                            anchors.centerIn: parent
                            text: "Bluetooth"
                            color: "#ffffff"
                            font.family: "SF Mono"
                            font.weight: 600
                            font.pixelSize: 17
                        }
                        HoverHandler {
                            id: hover_bluetooth
                            onHoveredChanged: bluetooth_rectangle.hovered = hover_bluetooth.hovered
                        }
                        TapHandler{
                            onTapped : {
                            bluetooth_panel.implicitWidth === 0 ? bluetooth_panel.implicitWidth = 350 : bluetooth_panel.implicitWidth = 0
                            BluetoothService.scan()
                            }
                        }
                        Behavior on color {
                            ColorAnimation{duration:250;easing.type: Easing.OutCubic}
                        }
                    }
                    WifiList{
                        id: wifi_panel
                    }
                    BluetoothPanel{
                        id: bluetooth_panel
                    }
                    BackgroundWidgets{
                        id: background_widgets
                    }
                }
            }
        }
    }
}
