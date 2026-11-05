import QtQuick
import qs.theme
import qs.services
import qs.widgets

Item {
    id: root

    signal back()
    property bool embedded: false      // inside the Settings window: no back arrow
    property bool dragging: false

    width: 360
    height: 440

    onVisibleChanged: {
        if (visible) {
            Displays.refresh()
            Brightness.refresh()
            Ddc.refresh()
        }
    }

    PageHeader {
        showBack: !root.embedded
        x: 14; y: 14
        width: root.width - 28
        title: "Display"
        onBack: root.back()
    }

    Flickable {
        x: 14; y: 54
        width: root.width - 28
        height: root.height - 54 - 14
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 8

            // ---------- One card per monitor ----------
            Repeater {
                model: Displays.outputs

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    readonly property string mname: modelData.name
                    readonly property bool internal: mname.indexOf("eDP") === 0
                                                     || mname.indexOf("LVDS") === 0
                                                     || mname.indexOf("DSI") === 0
                    readonly property bool hasBrightness: internal || Ddc.has(mname)
                    readonly property real level: internal ? Brightness.percent : (Ddc.levels[mname] || 0)
                    readonly property var modeList: Displays.uniqueModes(modelData.modes)
                    readonly property string currentKey:
                        Displays.normMode(modelData.width + "x" + modelData.height + "@" + modelData.hz.toFixed(2))

                    property bool modesOpen: false

                    width: col.width
                    height: inner.implicitHeight + 24
                    radius: 18
                    color: Theme.surfaceSoft
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Column {
                        id: inner
                        x: 12; y: 12
                        width: parent.width - 24
                        spacing: 10

                        // Header
                        Item {
                            width: parent.width
                            height: 34

                            Rectangle {
                                width: 34; height: 34
                                radius: 17
                                color: Theme.border

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 14; height: 10
                                    radius: 2
                                    color: "transparent"
                                    border.width: 1.6
                                    border.color: Theme.foreground
                                }
                            }

                            Column {
                                x: 44
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: card.mname
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Text {
                                    text: card.modelData.width + "×" + card.modelData.height
                                          + " · " + Math.round(card.modelData.hz) + " Hz · " + card.modelData.scale + "×"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: card.mname === Displays.focused
                                text: "focused"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        // Brightness: internal screen (brightnessctl) or external (ddcutil, if supported)
                        Item {
                            width: parent.width
                            height: 22
                            visible: card.hasBrightness

                            SliderBar {
                                width: parent.width - 44
                                value: card.level
                                icon: "sun"
                                onMoved: v => {
                                    if (card.internal) Brightness.setPercent(v)
                                    else Ddc.setLevel(card.mname, v)
                                }
                                onPressedChanged: root.dragging = pressed
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(card.level * 100) + "%"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        // Scala
                        Row {
                            spacing: 6

                            Repeater {
                                model: ["1.0", "1.25", "1.5", "1.75", "2.0"]

                                delegate: Rectangle {
                                    readonly property bool current:
                                        Math.abs(parseFloat(modelData) - card.modelData.scale) < 0.01

                                    width: 56; height: 24
                                    radius: 12
                                    color: current ? Theme.accent
                                                   : (chip.containsMouse ? Theme.islandHover : Theme.island)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "×"
                                        color: parent.current ? Theme.island : Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.bold: parent.current
                                    }

                                    MouseArea {
                                        id: chip
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Displays.setScale(card.mname, parseFloat(modelData))
                                    }
                                }
                            }
                        }

                        // Resolution (click: opens the list)
                        Item {
                            width: parent.width
                            height: 20

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Resolution"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }

                            Text {
                                id: chevron
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: Theme.muted
                                font.pixelSize: 16
                                rotation: card.modesOpen ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.right: chevron.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.modelData.width + "×" + card.modelData.height
                                      + " @ " + Math.round(card.modelData.hz) + " Hz"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.modesOpen = !card.modesOpen
                            }
                        }

                        // List of available resolutions
                        Item {
                            width: parent.width
                            height: Math.min(modesCol.implicitHeight, 132)
                            visible: card.modesOpen
                            clip: true

                            Flickable {
                                anchors.fill: parent
                                contentHeight: modesCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Column {
                                    id: modesCol
                                    width: parent.width
                                    spacing: 3

                                    Repeater {
                                        model: card.modeList

                                        delegate: Rectangle {
                                            required property string modelData

                                            readonly property bool current:
                                                Displays.normMode(modelData) === card.currentKey

                                            width: modesCol.width
                                            height: 26
                                            radius: 13
                                            color: current ? Theme.accent
                                                           : (modeMouse.containsMouse ? Theme.islandHover : Theme.island)

                                            Text {
                                                anchors.centerIn: parent
                                                text: Displays.prettyMode(modelData)
                                                color: parent.current ? Theme.island : Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.bold: parent.current
                                            }

                                            MouseArea {
                                                id: modeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Displays.setMode(card.mname, modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------- Luce notturna ----------
            Rectangle {
                width: col.width
                height: 100
                radius: 18
                color: Theme.surfaceSoft

                Rectangle {
                    x: 12; y: 12
                    width: 34; height: 34
                    radius: 17
                    color: NightLight.on ? Theme.accent : Theme.border
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Glyph {
                        anchors.centerIn: parent
                        kind: "moon"
                        size: 16
                        color: NightLight.on ? Theme.island : Theme.foreground
                    }
                }

                Column {
                    x: 56
                    y: 12 + 17 - height / 2
                    spacing: 1

                    Text {
                        text: "Night Light"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        text: NightLight.temperature + " K"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Toggle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 12 + 17 - height / 2
                    checked: NightLight.on
                    onToggled: NightLight.toggle()
                }

                SliderBar {
                    x: 12; y: 60
                    width: parent.width - 24
                    value: (NightLight.temperature - 2500) / 4000
                    icon: "moon"
                    onMoved: v => NightLight.setTemperature(2500 + v * 4000)
                    onPressedChanged: root.dragging = pressed
                }
            }
        }
    }
}
