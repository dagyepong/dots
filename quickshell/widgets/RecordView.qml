import QtQuick
import Quickshell
import qs.theme
import qs.services

// Recording menu (right click on the pill):
// stop, screen to record, audio, microphone mute
Item {
    id: root

    implicitHeight: col.y + col.implicitHeight + 16

    readonly property var audioModes: [
        { id: "off",    a: "volume", b: "",       lvl: 0, label: "No audio" },
        { id: "mic",    a: "mic",    b: "",       lvl: 2, label: "Microphone" },
        { id: "system", a: "volume", b: "",       lvl: 2, label: "System sound" },
        { id: "both",   a: "mic",    b: "volume", lvl: 2, label: "Microphone + system" }
    ]

    function audioLabel() {
        for (let i = 0; i < audioModes.length; i++)
            if (audioModes[i].id === Capture.audioMode) return audioModes[i].label
        return ""
    }

    function sourceLabel(n) {
        return n.description || n.nickname || n.name
    }

    function micLabel() {
        if (Capture.micName !== "") {
            for (let i = 0; i < Audio.sources.length; i++)
                if (Audio.sources[i].name === Capture.micName) return sourceLabel(Audio.sources[i])
            return Capture.micName
        }
        return Audio.micReady ? sourceLabel(Audio.source) : "No microphone"
    }

    // Pill button: icons or text go inside
    component Pill: Rectangle {
        id: pill

        property bool selected: false
        signal clicked()

        implicitHeight: 30
        radius: height / 2
        color: selected ? Theme.accent : (pillMouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft)
        Behavior on color { ColorAnimation { duration: 100 } }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    Column {
        id: col

        x: 20
        y: 16
        width: root.width - 40
        spacing: 12

        // ---------- Header: time and stop ----------
        Item {
            width: parent.width
            height: 34

            Rectangle {
                width: 34; height: 34
                radius: 17
                color: Theme.border

                Glyph {
                    anchors.centerIn: parent
                    kind: "record"
                    size: 17
                    color: Capture.recording ? Theme.danger : Theme.foreground
                }
            }

            Column {
                x: 44
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: Capture.recording ? Capture.timeText : "Recording"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: Capture.recording ? (Capture.paused ? "Paused" : "In progress") : "Next recording"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            // Pause / resume: the video stops and restarts, the file stays a single one
            Rectangle {
                visible: Capture.recording
                anchors.right: parent.right
                anchors.rightMargin: 42
                width: 34; height: 34
                radius: 17
                color: Capture.paused ? Theme.accent : (pauseMouse.containsMouse ? Theme.islandHover : Theme.border)
                Behavior on color { ColorAnimation { duration: 100 } }

                Glyph {
                    anchors.centerIn: parent
                    kind: Capture.paused ? "play" : "pause"
                    size: 14
                    color: Capture.paused ? Theme.island : Theme.foreground
                }

                MouseArea {
                    id: pauseMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Capture.togglePause()
                }
            }

            Rectangle {
                visible: Capture.recording
                anchors.right: parent.right
                width: 34; height: 34
                radius: 17
                color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, stopMouse.containsMouse ? 0.35 : 0.2)
                Behavior on color { ColorAnimation { duration: 100 } }

                Glyph {
                    anchors.centerIn: parent
                    kind: "stop"
                    size: 14
                    color: Theme.danger
                }

                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Capture.stopRecording()
                        UiState.recMenuOpen = false
                    }
                }
            }
        }

        // ---------- Screen ----------
        Text {
            text: "Screen"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Flow {
            width: parent.width
            spacing: 6

            Pill {
                width: autoLabel.implicitWidth + 28
                selected: Capture.outName === ""
                onClicked: Capture.outName = ""

                Text {
                    id: autoLabel
                    anchors.centerIn: parent
                    text: "Auto"
                    color: parent.selected ? Theme.island : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: parent.selected
                }
            }

            Repeater {
                model: Quickshell.screens

                delegate: Pill {
                    id: scr

                    required property var modelData

                    width: scrLabel.implicitWidth + 28
                    selected: Capture.outName === modelData.name
                    onClicked: Capture.outName = modelData.name

                    Text {
                        id: scrLabel
                        anchors.centerIn: parent
                        text: scr.modelData.name
                        color: scr.selected ? Theme.island : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: scr.selected
                    }
                }
            }
        }

        // ---------- Audio ----------
        Item {
            width: parent.width
            height: 12

            Text {
                text: "Audio"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                anchors.right: parent.right
                text: root.audioLabel()
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        Row {
            spacing: 6

            Repeater {
                model: root.audioModes

                delegate: Pill {
                    id: am

                    required property var modelData

                    width: 62
                    selected: Capture.audioMode === modelData.id
                    onClicked: Capture.audioMode = modelData.id

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Glyph {
                            kind: am.modelData.a
                            level: am.modelData.lvl
                            size: 14
                            color: am.selected ? Theme.island : Theme.foreground
                        }

                        Glyph {
                            visible: am.modelData.b !== ""
                            kind: am.modelData.b !== "" ? am.modelData.b : "volume"
                            size: 14
                            color: am.selected ? Theme.island : Theme.foreground
                        }
                    }
                }
            }
        }

        // ---------- Microphone: mute and input choice ----------
        Rectangle {
            visible: Capture.usesMic
            width: parent.width
            height: micCol.implicitHeight + 20
            radius: 18
            color: Theme.surfaceSoft

            Column {
                id: micCol

                x: 10
                y: 10
                width: parent.width - 20
                spacing: 8

                Item {
                    width: parent.width
                    height: 34

                    Rectangle {
                        width: 34; height: 34
                        radius: 17
                        opacity: Capture.recording ? 1 : 0.4
                        color: Capture.micMuted
                               ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25)
                               : (muteMouse.containsMouse && Capture.recording ? Theme.islandHover : Theme.border)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Glyph {
                            anchors.centerIn: parent
                            kind: "mic"
                            level: Capture.micMuted ? 0 : 2
                            size: 16
                            color: Capture.micMuted ? Theme.danger : Theme.foreground
                        }

                        MouseArea {
                            id: muteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: Capture.recording
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Capture.toggleMicMute()
                        }
                    }

                    Column {
                        x: 44
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        spacing: 1

                        Text {
                            width: parent.width
                            text: root.micLabel()
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: Capture.recording ? (Capture.micMuted ? "Muted" : "Live") : ""
                            visible: text !== ""
                            color: Capture.micMuted ? Theme.danger : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                // Input selection (only if there is more than one)
                Flickable {
                    visible: Audio.sources.length > 1
                    width: parent.width
                    height: Math.min(srcCol.implicitHeight, 3 * 28)
                    contentHeight: srcCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: srcCol
                        width: parent.width
                        spacing: 3

                        Pill {
                            width: srcCol.width
                            height: 25
                            selected: Capture.micName === ""
                            onClicked: Capture.micName = ""

                            Text {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Default"
                                color: parent.selected ? Theme.island : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: parent.selected
                            }
                        }

                        Repeater {
                            model: Audio.sources.length > 1 ? Audio.sources : []

                            delegate: Pill {
                                id: src

                                required property var modelData

                                width: srcCol.width
                                height: 25
                                selected: Capture.micName === modelData.name
                                onClicked: Capture.micName = modelData.name

                                Text {
                                    x: 12
                                    width: parent.width - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.sourceLabel(src.modelData)
                                    color: src.selected ? Theme.island : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: src.selected
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
