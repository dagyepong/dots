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

    // Reusable mute button
    component MuteBtn: Rectangle {
        id: mb

        property bool muted: false
        property string icon: "volume"
        signal clicked()

        width: 26
        height: 26
        radius: 13
        color: muted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25)
                     : (mbMouse.containsMouse ? Theme.islandHover : Theme.border)

        Glyph {
            anchors.centerIn: parent
            kind: mb.icon
            level: mb.muted ? 0 : 2
            size: 13
            color: mb.muted ? Theme.danger : Theme.foreground
        }

        MouseArea {
            id: mbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }

    PageHeader {
        showBack: !root.embedded
        x: 14; y: 14
        width: root.width - 28
        title: "Sound"
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

            // ---------- Main volume ----------
            Rectangle {
                width: col.width
                height: 72
                radius: 16
                color: Theme.surfaceSoft

                Text {
                    x: 14; y: 8
                    text: "Volume"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 8
                    text: Math.round(Audio.volume * 100) + "%"
                    color: Audio.volume > 1.0005 ? Theme.danger : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                MixSlider {
                    x: 12; y: 32
                    width: parent.width - 12 - 14 - 26 - 8
                    value: Audio.volume
                    icon: "volume"
                    iconLevel: Audio.muted ? 0 : 2
                    onMoved: v => Audio.setVolume(v)
                    onPressedChanged: root.dragging = pressed
                }

                MuteBtn {
                    x: parent.width - 14 - 26
                    y: 30
                    muted: Audio.muted
                    onClicked: Audio.toggleMute()
                }
            }

            // ---------- Uscite ----------
            Text {
                x: 4
                text: "Output"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Repeater {
                model: Audio.sinks

                delegate: ListRow {
                    required property var modelData

                    readonly property bool isDefault: Audio.sink === modelData

                    width: col.width
                    icon: "volume"
                    iconLevel: 2
                    title: modelData.description || modelData.nickname || modelData.name
                    subtitle: isDefault ? "In use" : ""
                    trailing: isDefault ? "" : "Use"
                    active: isDefault
                    onClicked: Audio.setDefault(modelData)
                }
            }

            // ---------- One volume per app ----------
            Text {
                x: 4
                text: "App"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                x: 4
                visible: Audio.apps.length === 0
                text: "No app is playing audio"
                color: Theme.muted
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Repeater {
                model: Audio.apps

                delegate: Rectangle {
                    id: appRow

                    required property var modelData

                    readonly property var au: modelData.audio
                    readonly property string appName: {
                        const p = modelData.properties
                        return (p && (p["application.name"] || p["application.process.binary"]))
                               || modelData.nickname || modelData.description || modelData.name
                    }

                    width: col.width
                    height: 62
                    radius: 16
                    color: Theme.surfaceSoft

                    Text {
                        x: 14; y: 8
                        width: parent.width - 80
                        text: appRow.appName
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 8
                        text: appRow.au ? Math.round(appRow.au.volume * 100) + "%" : ""
                        color: (appRow.au && appRow.au.volume > 1.0005) ? Theme.danger : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    MixSlider {
                        x: 12; y: 32
                        width: parent.width - 12 - 14 - 26 - 8
                        value: appRow.au ? appRow.au.volume : 0
                        icon: "volume"
                        iconLevel: (appRow.au && appRow.au.muted) ? 0 : 2
                        onMoved: v => { if (appRow.au) appRow.au.volume = Math.max(0, Math.min(Audio.maxVolume, v)) }
                        onPressedChanged: root.dragging = pressed
                    }

                    MuteBtn {
                        x: parent.width - 14 - 26
                        y: 30
                        muted: appRow.au ? appRow.au.muted : false
                        onClicked: { if (appRow.au) appRow.au.muted = !appRow.au.muted }
                    }
                }
            }

            // ---------- Microfono ----------
            Text {
                x: 4
                text: "Microphone"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Rectangle {
                width: col.width
                height: 72
                radius: 16
                color: Theme.surfaceSoft

                Text {
                    x: 14; y: 8
                    text: Audio.micReady ? (Audio.source.description || Audio.source.name) : "No microphone"
                    width: parent.width - 80
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 8
                    text: Math.round(Audio.micVolume * 100) + "%"
                    color: Audio.micVolume > 1.0005 ? Theme.danger : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                MixSlider {
                    x: 12; y: 32
                    width: parent.width - 12 - 14 - 26 - 8
                    value: Audio.micVolume
                    icon: "mic"
                    iconLevel: Audio.micMuted ? 0 : 2
                    enabled: Audio.micReady
                    onMoved: v => Audio.setMicVolume(v)
                    onPressedChanged: root.dragging = pressed
                }

                MuteBtn {
                    x: parent.width - 14 - 26
                    y: 30
                    icon: "mic"
                    muted: Audio.micMuted
                    onClicked: Audio.toggleMicMute()
                }
            }

            // Input selection (only if there is more than one)
            Repeater {
                model: Audio.sources.length > 1 ? Audio.sources : []

                delegate: ListRow {
                    required property var modelData

                    readonly property bool isDefault: Audio.source === modelData

                    width: col.width
                    icon: "mic"
                    title: modelData.description || modelData.nickname || modelData.name
                    subtitle: isDefault ? "In use" : ""
                    trailing: isDefault ? "" : "Use"
                    active: isDefault
                    onClicked: Audio.setDefaultSource(modelData)
                }
            }
        }
    }
}
