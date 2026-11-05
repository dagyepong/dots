import QtQuick
import qs.theme
import qs.services
import qs.widgets

// Page 3: connected monitors (on/off, position, rotation, mirror)
Item {
    id: root

    signal openPage(string name)
    property bool dragging: false

    width: 360
    height: 406

    onVisibleChanged: if (visible) Displays.refresh()

    function rotation(o) {
        if (Compositor.isHyprland) return (parseInt(o.transform) || 0) % 4 * 90
        const m = { "Normal": 0, "90": 90, "180": 180, "270": 270 }
        return m[o.transform] !== undefined ? m[o.transform] : -1
    }

    readonly property bool several: Displays.outputs.length > 1

    // First "other" monitor besides the internal one, for the Mirror button
    function mirrorPair() {
        const on = Displays.onList()
        if (on.length < 2) return null
        let src = on[0]
        for (let i = 0; i < on.length; i++) if (Displays.isInternal(on[i].name)) { src = on[i]; break }
        for (let i = 0; i < on.length; i++) if (on[i].name !== src.name) return { src: src.name, dst: on[i].name }
        return null
    }

    Flickable {
        x: 14; y: 8
        width: 332
        height: root.height - 8 - 14
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 8

            // ---------- Modi rapidi ----------
            Rectangle {
                width: col.width
                height: 76
                radius: 18
                color: Theme.surfaceSoft

                Text {
                    x: 14; y: 9
                    text: "Quick layout"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Row {
                    x: 10; y: 30
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "internal", l: "Built-in", i: "keyboard" },
                            { id: "external", l: "External", i: "screen" },
                            { id: "extend",   l: "Extend",   i: "screen" },
                            { id: "mirror",   l: "Mirror",   i: "screen" }
                        ]

                        delegate: Chip {
                            required property var modelData

                            width: 74; height: 30
                            label: modelData.l
                            enabled: modelData.id === "internal" || root.several || modelData.id === "external"
                            selected: modelData.id === "mirror" && Displays.mirrorFrom !== ""
                            onClicked: {
                                if (modelData.id === "internal") Displays.onlyInternal()
                                else if (modelData.id === "external") Displays.onlyExternal()
                                else if (modelData.id === "extend") Displays.extend()
                                else {
                                    const p = root.mirrorPair()
                                    if (Displays.mirrorFrom !== "") Displays.stopMirror()
                                    else if (p) Displays.mirror(p.src, p.dst)
                                    else Displays.toast("Mirror needs two screens turned on")
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 9
                    visible: Displays.mirrorFrom !== ""
                    text: Displays.mirrorFrom + " → " + Displays.mirrorTo
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            // ---------- List header ----------
            Item {
                width: col.width
                height: 14

                Text {
                    x: 6
                    text: "Screens"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    text: "Identify"
                    color: idMouse.containsMouse ? Theme.foreground : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10

                    MouseArea {
                        id: idMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Displays.identify()
                    }
                }
            }

            // ---------- One card per monitor ----------
            Repeater {
                model: Displays.outputs

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    readonly property bool isOn: modelData.on
                    readonly property string side: Displays.sideOf(modelData.name)
                    readonly property int rot: root.rotation(modelData)

                    width: col.width
                    height: inner.implicitHeight + 24
                    radius: 18
                    color: Theme.surfaceSoft
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Column {
                        id: inner
                        x: 12; y: 12
                        width: parent.width - 24
                        spacing: 10

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
                                width: parent.width - 44 - 52
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: card.modelData.name + (card.modelData.label !== "" ? " · " + card.modelData.label : "")
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
                            height: 28
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
                                spacing: 4

                                Repeater {
                                    model: [{ s: "left", l: "←" }, { s: "above", l: "↑" }, { s: "below", l: "↓" }, { s: "right", l: "→" }]

                                    delegate: Chip {
                                        required property var modelData

                                        width: 44; height: 26
                                        label: modelData.l
                                        selected: card.side === modelData.s
                                        onClicked: Displays.place(card.modelData.name, modelData.s)
                                    }
                                }
                            }
                        }

                        // Rotazione
                        Item {
                            width: parent.width
                            height: 28
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
                                spacing: 4

                                Repeater {
                                    model: [0, 90, 180, 270]

                                    delegate: Chip {
                                        required property int modelData

                                        width: 44; height: 26
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
                            height: 20
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
                                onClicked: root.openPage("display")
                            }
                        }
                    }
                }
            }

            Text {
                width: col.width
                visible: Displays.outputs.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No screens detected"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
