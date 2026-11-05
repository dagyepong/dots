import QtQuick
import qs.theme
import qs.services

// One card per monitor: on/off, position relative to the others, rotation
Rectangle {
    id: card

    required property var modelData
    signal openDisplay()

    readonly property bool isOn: modelData.on
    readonly property string side: Displays.sideOf(modelData.name)
    readonly property int rot: {
        const t = modelData.transform
        if (Compositor.isHyprland) return (parseInt(t) || 0) % 4 * 90
        const m = { "Normal": 0, "90": 90, "180": 180, "270": 270 }
        return m[t] !== undefined ? m[t] : -1
    }

    height: inner.implicitHeight + 24
    radius: 20
    color: Theme.surfaceSoft
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Column {
        id: inner
        x: 12; y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width
            height: 34

            Rectangle {
                width: 34; height: 34
                radius: 17
                color: card.isOn ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: 140 } }

                Glyph {
                    anchors.centerIn: parent
                    kind: Displays.isInternal(card.modelData.name) ? "keyboard" : "screen"
                    size: 16
                    color: card.isOn ? Theme.island : Theme.foreground
                }
            }

            Column {
                x: 44
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - 50
                spacing: 1

                Text {
                    width: parent.width
                    text: card.modelData.name
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: card.isOn
                          ? card.modelData.width + "×" + card.modelData.height + " · "
                            + Math.round(card.modelData.hz) + " Hz · " + card.modelData.scale + "×"
                          : "Off"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: card.isOn
                onToggled: Displays.setEnabled(card.modelData.name, !card.isOn)
            }
        }

        // Position relative to the other screen
        Item {
            width: parent.width
            height: 26
            visible: card.isOn && Displays.refFor(card.modelData.name) !== null

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Position"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Row {
                anchors.right: parent.right
                spacing: 3

                Repeater {
                    model: [{ s: "left", l: "←" }, { s: "above", l: "↑" }, { s: "below", l: "↓" }, { s: "right", l: "→" }]

                    delegate: Chip {
                        required property var modelData

                        width: 34; height: 24
                        label: modelData.l
                        selected: card.side === modelData.s
                        onClicked: Displays.place(card.modelData.name, modelData.s)
                    }
                }
            }
        }

        // Rotation
        Item {
            width: parent.width
            height: 26
            visible: card.isOn

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Rotation"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Row {
                anchors.right: parent.right
                spacing: 3

                Repeater {
                    model: [0, 90, 180, 270]

                    delegate: Chip {
                        required property int modelData

                        width: 34; height: 24
                        label: modelData + "°"
                        selected: card.rot === modelData
                        onClicked: Displays.setTransform(card.modelData.name, modelData)
                    }
                }
            }
        }

        // Scale, resolution, brightness: in the Display page
        Item {
            width: parent.width
            height: 18
            visible: card.isOn

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Resolution, scale, brightness"
                color: more.containsMouse ? Theme.foreground : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: Theme.muted
                font.pixelSize: 16
            }

            MouseArea {
                id: more
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.openDisplay()
            }
        }
    }
}
