import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Item {
    id: root

    signal back()
    signal pasted()
    property bool dragging: false
    property int tab: 0                  // 0 = timer, 1 = cronometro

    width: 360
    height: 546

    // Pulsantino riusabile
    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string icon: ""             // if set, replaces the text
        property bool accent: false
        property bool selected: false
        signal clicked()

        implicitHeight: 28
        radius: height / 2
        color: selected ? Theme.accent
               : (chipMouse.containsMouse ? Theme.islandHover : (accent ? Theme.border : Theme.island))
        opacity: enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 100 } }

        Glyph {
            anchors.centerIn: parent
            visible: chip.icon !== ""
            kind: chip.icon !== "" ? chip.icon : "play"
            size: 14
            color: chip.selected ? Theme.island : Theme.foreground
        }

        Text {
            anchors.centerIn: parent
            visible: chip.icon === ""
            text: chip.label
            color: chip.selected ? Theme.island : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: chip.selected || chip.accent
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    onVisibleChanged: {
        ClipHist.active = visible
        if (visible) ClipHist.refresh()
    }

    // ---------- Layout tastiera ----------
    // Keyboard layout: name on the left, a button for each layout on the right
    Rectangle {
        x: 14; y: 54
        width: 332
        height: 46
        radius: 23
        color: Theme.surfaceSoft

        Rectangle {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
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
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            width: 98
            spacing: 1

            Text {
                width: parent.width
                text: "Keyboard"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
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

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Repeater {
                model: KbLayout.layouts

                delegate: Chip {
                    required property var modelData

                    width: 32; height: 26
                    label: modelData.code
                    selected: KbLayout.xkb === modelData.xkb
                    onClicked: KbLayout.setLayout(modelData.xkb)
                }
            }
        }
    }

    // ---------- Benvenuto all'accesso ----------
    Rectangle {
        x: 14; y: 110
        width: 332
        height: 40
        radius: 20
        color: Theme.surfaceSoft

        Rectangle {
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30
            radius: 15
            color: HelloState.enabled ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: 140 } }

            Glyph {
                anchors.centerIn: parent
                kind: "star"
                size: 14
                color: HelloState.enabled ? Theme.island : Theme.foreground
            }
        }

        Text {
            x: 46
            anchors.verticalCenter: parent.verticalCenter
            text: "Welcome"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            x: 112
            anchors.verticalCenter: parent.verticalCenter
            text: HelloState.enabled ? "On" : "Off"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Chip {
            anchors.right: helloToggle.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 26
            icon: "play"
            onClicked: {
                HelloState.preview()
                root.pasted()
            }
        }

        Toggle {
            id: helloToggle
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            checked: HelloState.enabled
            onToggled: HelloState.toggle()
        }
    }

    // ---------- Timer e cronometro ----------
    Rectangle {
        x: 14; y: 160
        width: 332
        height: 158
        radius: 18
        color: Theme.surfaceSoft

        Row {
            x: 12; y: 12
            spacing: 6

            Chip {
                width: 46; height: 26
                icon: "hourglass"
                selected: root.tab === 0
                onClicked: root.tab = 0
            }

            Chip {
                width: 46; height: 26
                icon: "stopwatch"
                selected: root.tab === 1
                onClicked: root.tab = 1
            }
        }

        // Lit dot = running
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 21.5
            width: 7; height: 7
            radius: 3.5
            color: Theme.accent
            visible: root.tab === 0 ? Chrono.timerRunning : Chrono.swRunning
        }

        Text {
            y: 42
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.tab === 0 ? Chrono.timerText : Chrono.swText
            color: (root.tab === 0 && Chrono.timerDone) ? Theme.danger : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 36
            font.bold: true
        }

        // ----- Timer -----
        Item {
            visible: root.tab === 0
            x: 14; y: 94
            width: 304
            height: 58

            Row {
                y: 0
                spacing: 6

                Repeater {
                    model: [60, 300, 600, 1500, 2700]

                    delegate: Chip {
                        required property int modelData

                        width: 56
                        label: Math.round(modelData / 60)
                        onClicked: Chrono.quick(modelData)
                    }
                }
            }

            Row {
                y: 30
                spacing: 6

                Chip { width: 40; label: "−1"; onClicked: Chrono.addTime(-60) }
                Chip { width: 40; label: "+1"; onClicked: Chrono.addTime(60) }
                Chip { width: 40; label: "+5"; onClicked: Chrono.addTime(300) }

                Item { width: 6; height: 1 }

                Chip {
                    width: 72
                    accent: true
                    icon: Chrono.timerRunning ? "pause" : "play"
                    onClicked: Chrono.timerToggle()
                }

                Chip {
                    width: 72
                    icon: "reboot"
                    onClicked: Chrono.timerReset()
                }
            }
        }

        // ----- Cronometro -----
        Item {
            visible: root.tab === 1
            x: 14; y: 94
            width: 304
            height: 58

            Text {
                width: parent.width
                height: 28
                text: Chrono.lapsText
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Row {
                y: 30
                spacing: 6

                Chip {
                    width: 98
                    accent: true
                    icon: Chrono.swRunning ? "pause" : "play"
                    onClicked: Chrono.swToggle()
                }

                Chip {
                    width: 98
                    icon: "flag"
                    enabled: Chrono.swRunning
                    onClicked: Chrono.swLap()
                }

                Chip {
                    width: 98
                    icon: "reboot"
                    onClicked: Chrono.swReset()
                }
            }
        }
    }

    // ---------- Clipboard ----------
    Text {
        x: 18; y: 328
        text: "Clipboard"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 328
        visible: ClipHist.items.length > 0
        text: "Clear"
        color: wipeMouse.containsMouse ? Theme.foreground : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10

        MouseArea {
            id: wipeMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ClipHist.wipe()
        }
    }

    Text {
        x: 18; y: 354
        width: 324
        visible: !ClipHist.available
        wrapMode: Text.WordWrap
        text: "Clipboard history needs cliphist, wl-clipboard and wtype:\nsudo pacman -S --needed cliphist wl-clipboard wtype"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Flickable {
        x: 14; y: 348
        width: 332
        height: root.height - 348 - 14
        contentHeight: col.implicitHeight
        clip: true
        visible: ClipHist.available
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 6

            Text {
                x: 4
                visible: ClipHist.items.length === 0
                text: "Nothing yet: copy something and it will show up here"
                color: Theme.muted
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Repeater {
                model: ClipHist.items

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    readonly property bool img: modelData.isImage

                    width: col.width
                    height: img ? 66 : 42
                    radius: 14
                    color: rowMouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ClipHist.paste(row.modelData.id)
                            root.pasted()
                        }
                    }

                    ClippingRectangle {
                        visible: row.img
                        x: 8; y: 8
                        width: 68; height: 50
                        radius: 10
                        color: Theme.island

                        Image {
                            anchors.fill: parent
                            source: ClipHist.ready[row.modelData.id]
                                    ? "file://" + ClipHist.thumbDir + "/" + row.modelData.id : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(160, 120)
                        }
                    }

                    Text {
                        x: row.img ? 88 : 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 34
                        text: row.img ? "Image · " + row.modelData.w + "×" + row.modelData.h
                                      : row.modelData.preview
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"
                        color: Theme.muted
                        font.pixelSize: 17

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipHist.remove(row.modelData.raw)
                        }
                    }
                }
            }
        }
    }
}
