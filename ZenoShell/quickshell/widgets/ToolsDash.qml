import QtQuick
import qs.theme
import qs.services

// Dashboard page 2: keyboard layout · welcome · timer and stopwatch · clipboard
Item {
    id: root

    signal pasted()
    property bool dragging: false
    property int tab: 0                  // 0 = timer, 1 = stopwatch

    width: 860
    height: 308

    onVisibleChanged: {
        ClipHist.active = visible
        if (visible) ClipHist.refresh()
    }

    // ---------- Keyboard layout ----------
    Rectangle {
        x: 14; y: 0
        width: 262; height: 192
        radius: 22
        color: Theme.surfaceSoft

        Rectangle {
            x: 10; y: 10
            width: 34; height: 34
            radius: 17
            color: Theme.accent

            Glyph {
                anchors.centerIn: parent
                kind: "keyboard"
                size: 16
                color: Theme.island
            }
        }

        Column {
            x: 54; y: 10
            width: parent.width - 54 - 12
            height: 34
            spacing: 1

            Text {
                width: parent.width
                text: "Keyboard"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                width: parent.width
                text: KbLayout.name !== "" ? KbLayout.name : "Not detected"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Column {
            x: 10; y: 54
            width: parent.width - 20
            spacing: 3

            Repeater {
                model: KbLayout.layouts

                delegate: Chip {
                    required property var modelData

                    width: parent.width
                    height: 22
                    radius: 11
                    selected: KbLayout.xkb === modelData.xkb
                    onClicked: KbLayout.setLayout(modelData.xkb)

                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.code
                        color: parent.selected ? Theme.island : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Text {
                        x: 44
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.selected ? Theme.island : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: parent.selected
                    }
                }
            }
        }
    }

    // ---------- Welcome ----------
    Rectangle {
        x: 14; y: 202
        width: 262; height: 106
        radius: 22
        color: Theme.surfaceSoft

        Rectangle {
            x: 10; y: 10
            width: 34; height: 34
            radius: 17
            color: HelloState.enabled ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: 140 } }

            Glyph {
                anchors.centerIn: parent
                kind: "star"
                size: 16
                color: HelloState.enabled ? Theme.island : Theme.foreground
            }
        }

        Column {
            x: 54; y: 10
            height: 34
            spacing: 1

            Text {
                text: "Welcome"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: HelloState.enabled ? "On · quote at login" : "Off"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        Toggle {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 17
            checked: HelloState.enabled
            onToggled: HelloState.toggle()
        }

        Chip {
            x: 10; y: 58
            width: parent.width - 20
            height: 34
            accent: true
            label: "Preview"
            onClicked: {
                HelloState.preview()
                root.pasted()
            }
        }
    }

    // ---------- Timer and stopwatch ----------
    Rectangle {
        x: 286; y: 0
        width: 296; height: 308
        radius: 22
        color: Theme.surfaceSoft

        Row {
            x: 14; y: 14
            spacing: 6

            Chip {
                width: 50; height: 28
                icon: "hourglass"
                selected: root.tab === 0
                onClicked: root.tab = 0
            }

            Chip {
                width: 50; height: 28
                icon: "stopwatch"
                selected: root.tab === 1
                onClicked: root.tab = 1
            }
        }

        // Lit dot = running
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 24
            width: 8; height: 8
            radius: 4
            color: Theme.accent
            visible: root.tab === 0 ? Chrono.timerRunning : Chrono.swRunning
        }

        Text {
            y: 62
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.tab === 0 ? Chrono.timerText : Chrono.swText
            color: (root.tab === 0 && Chrono.timerDone) ? Theme.danger : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 52
            font.bold: true
        }

        // ----- Timer -----
        Item {
            visible: root.tab === 0
            x: 14; y: 150
            width: parent.width - 28
            height: 140

            Row {
                y: 0
                spacing: 6

                Repeater {
                    model: [60, 300, 600, 1500, 2700]

                    delegate: Chip {
                        required property int modelData

                        width: 48; height: 30
                        label: Math.round(modelData / 60)
                        onClicked: Chrono.quick(modelData)
                    }
                }
            }

            Row {
                y: 40
                spacing: 6

                Chip { width: 48; height: 30; label: "−1"; onClicked: Chrono.addTime(-60) }
                Chip { width: 48; height: 30; label: "+1"; onClicked: Chrono.addTime(60) }
                Chip { width: 48; height: 30; label: "+5"; onClicked: Chrono.addTime(300) }
                Chip { width: 48; height: 30; label: "+10"; onClicked: Chrono.addTime(600) }
            }

            Row {
                y: 84
                spacing: 8

                Chip {
                    width: 134; height: 40
                    accent: true
                    icon: Chrono.timerRunning ? "pause" : "play"
                    onClicked: Chrono.timerToggle()
                }

                Chip {
                    width: 134; height: 40
                    icon: "reboot"
                    onClicked: Chrono.timerReset()
                }
            }
        }

        // ----- Stopwatch -----
        Item {
            visible: root.tab === 1
            x: 14; y: 150
            width: parent.width - 28
            height: 140

            Text {
                width: parent.width
                height: 40
                text: Chrono.lapsText
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 3
            }

            Row {
                y: 84
                spacing: 6

                Chip {
                    width: 88; height: 40
                    accent: true
                    icon: Chrono.swRunning ? "pause" : "play"
                    onClicked: Chrono.swToggle()
                }

                Chip {
                    width: 88; height: 40
                    icon: "flag"
                    enabled: Chrono.swRunning
                    onClicked: Chrono.swLap()
                }

                Chip {
                    width: 88; height: 40
                    icon: "reboot"
                    onClicked: Chrono.swReset()
                }
            }
        }
    }

    // ---------- Clipboard ----------
    ClipCard {
        x: 592; y: 0
        width: 254; height: 308
        onPasted: root.pasted()
    }
}
