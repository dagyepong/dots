import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The card that drops over the phone's screen when you right-click the
// Night Light tile — same idea (and same look) as BluetoothDialog.qml,
// but a settings card instead of a list:
//
//   Intensity   how warm the screen goes while Night Light is ON
//               (hyprsunset's colour temperature, 6000K = no tint down
//               to 2500K = very warm). Dragging it also switches Night
//               Light on, so you see what you're choosing.
//   Automatic   turn Night Light on by itself between two times of day
//               and back off again afterwards. A manual click on the
//               tile still wins until the next start/end time.
//
// Pure UI: QuickPanelFace.qml feeds it the state and turns its signals
// into calls on QuickSource.qml (via QuickPanel.qml).
Item {
    id: root

    property bool open: false
    property bool nightOn: false
    property int temperature: 4500        // Kelvin
    property bool autoOn: false
    property int autoFrom: 20             // hour of day, 0-23
    property int autoTo: 6

    readonly property int minKelvin: 2500
    readonly property int maxKelvin: 6000  // hyprsunset's "no tint"

    // 0 (no tint) .. 100 (warmest), for the label.
    readonly property int intensityPercent:
        Math.round((root.maxKelvin - root.temperature) / (root.maxKelvin - root.minKelvin) * 100)

    signal closeRequested()
    signal toggleRequested()
    signal temperatureMoved(int kelvin)
    signal autoRequested(bool on)
    signal scheduleRequested(int from, int to)

    function hourLabel(h) {
        const hh = ((h % 24) + 24) % 24
        return ((hh + 11) % 12 + 1) + ":00 " + (hh < 12 ? "AM" : "PM")
    }

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? 140 : 220
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.phoneScreenInset
        radius: Theme.phoneCornerRadius - Theme.phoneScreenInset
        color: Theme.scrim
        opacity: root.open ? 0.55 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
        antialiasing: true
    }

    Rectangle {
        x: 40 + (Theme.quickFlat ? 0 : 5)
        y: 200 + 4
        width: 575
        height: card.height
        radius: 41
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card
        x: 40
        y: 200
        width: 575
        height: 470
        radius: 41
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        clip: true

        MouseArea { anchors.fill: parent }

        Text {
            x: 28
            y: 26
            text: "Night Light"
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        // ON / OFF, the same as clicking the tile.
        Rectangle {
            id: powerButton
            x: card.width - 28 - width
            y: 22
            width: powerLabel.implicitWidth + 28
            height: 34
            radius: 17
            color: root.nightOn ? Theme.accentMint : (powerArea.containsMouse ? Theme.pSurfaceHover : "transparent")
            border.width: 2
            border.color: Theme.pLine

            Text {
                id: powerLabel
                anchors.centerIn: parent
                text: root.nightOn ? "ON" : "OFF"
                color: root.nightOn ? Theme.colBorder : Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRequested()
            }
            antialiasing: true
        }

        // ===== intensity =====
        Text {
            x: 28
            y: 88
            text: "Intensity"
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            x: card.width - 28 - width
            y: 90
            text: root.temperature + "K  ·  " + root.intensityPercent + "%"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Item {
            id: slider
            x: 28
            y: 122
            width: card.width - 56
            height: 40

            // 0 at the cool end (6000K), 1 at the warm end (2500K).
            readonly property real ratio:
                (root.maxKelvin - root.temperature) / (root.maxKelvin - root.minKelvin)

            function setFromX(px) {
                const r = Math.max(0, Math.min(1, px / slider.width))
                const k = root.maxKelvin - r * (root.maxKelvin - root.minKelvin)
                root.temperatureMoved(Math.round(k / 50) * 50)
            }

            Rectangle {
                id: trackBar
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 16
                radius: 8
                border.width: 2
                border.color: Theme.pLine
                antialiasing: true
                opacity: root.nightOn ? 1 : 0.6
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#dcecff" }
                    GradientStop { position: 0.5; color: "#ffe3b8" }
                    GradientStop { position: 1.0; color: "#ff9a3c" }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            Rectangle {
                id: handle
                width: 30
                height: 30
                radius: 15
                x: slider.ratio * (slider.width - width)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.pSurface
                border.width: 3
                border.color: Theme.pLine
                antialiasing: true
                scale: sliderArea.pressed ? 1.12 : 1
                Behavior on scale {
                    NumberAnimation { duration: 90 }
                }
            }

            MouseArea {
                id: sliderArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => slider.setFromX(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        slider.setFromX(mouse.x)
                }
            }
        }

        Text {
            x: 28
            y: 166
            text: "Cool"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            x: card.width - 28 - width
            y: 166
            text: "Warm"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Rectangle {
            x: 28
            y: 202
            width: card.width - 56
            height: 2
            color: Theme.pSurfaceDivider
        }

        // ===== automatic =====
        Text {
            x: 28
            y: 224
            text: "Automatic"
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            x: 28
            y: 250
            text: "Turn on by itself between two times"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        // The switch.
        Rectangle {
            id: autoSwitch
            x: card.width - 28 - width
            y: 230
            width: 60
            height: 32
            radius: 16
            border.width: 3
            border.color: Theme.pLine
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.autoOn ? Theme.accentMint : Theme.pSurfaceDivider }
                GradientStop { position: 1.0; color: root.autoOn ? Theme.accentCyan : Theme.pSurfaceDivider }
            }

            Rectangle {
                width: 22
                height: 22
                radius: 11
                y: 3
                x: root.autoOn ? parent.width - width - 5 : 3
                color: Theme.pSurface
                border.width: 2
                border.color: Theme.pLine
                antialiasing: true
                Behavior on x {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.autoRequested(!root.autoOn)
            }
        }

        // From / Until: an hour stepper each.
        Repeater {
            model: [
                { label: "From", isFrom: true },
                { label: "Until", isFrom: false }
            ]

            delegate: Item {
                id: timeRow
                required property var modelData
                required property int index

                readonly property int hour: modelData.isFrom ? root.autoFrom : root.autoTo

                function step(delta) {
                    const h = ((timeRow.hour + delta) % 24 + 24) % 24
                    if (modelData.isFrom)
                        root.scheduleRequested(h, root.autoTo)
                    else
                        root.scheduleRequested(root.autoFrom, h)
                }

                x: 28
                y: 290 + index * 60
                width: card.width - 56
                height: 48
                opacity: root.autoOn ? 1 : 0.45
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: timeRow.modelData.label
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: minusArea.containsMouse ? Theme.pSurfaceHover : "transparent"
                        border.width: 2
                        border.color: Theme.pLine
                        antialiasing: true

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "remove"
                            size: 22
                            color: Theme.pInk
                        }

                        MouseArea {
                            id: minusArea
                            anchors.fill: parent
                            enabled: root.autoOn
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: timeRow.step(-1)
                        }
                    }

                    Text {
                        width: 96
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.hourLabel(timeRow.hour)
                        color: Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: plusArea.containsMouse ? Theme.pSurfaceHover : "transparent"
                        border.width: 2
                        border.color: Theme.pLine
                        antialiasing: true

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: 22
                            color: Theme.pInk
                        }

                        MouseArea {
                            id: plusArea
                            anchors.fill: parent
                            enabled: root.autoOn
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: timeRow.step(1)
                        }
                    }
                }
            }
        }

        Text {
            x: 28
            y: 422
            width: card.width - 56
            wrapMode: Text.Wrap
            text: "A click on the tile overrides Automatic until the next start or end time."
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }
}
