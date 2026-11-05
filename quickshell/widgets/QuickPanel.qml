import QtQuick
import qs.theme
import qs.services

// Panel: quick switches · light / sound / mic · CPU, RAM and battery live
Item {
    id: root

    signal openPanel(string name)

    width: 340
    height: 344

    property bool dragging: lightSlider.pressed || soundSlider.pressed || micSlider.pressed
    property bool counted: false

    // CPU and RAM need live readings while the panel is visible
    onVisibleChanged: {
        if (visible && !counted) { SysStats.users++; counted = true }
        else if (!visible && counted) { SysStats.users--; counted = false }
    }
    Component.onDestruction: if (counted) SysStats.users--

    // ---------- Switches ----------
    Grid {
        x: 14; y: 14
        columns: 2
        spacing: 10

        ControlTile {
            width: 151; height: 48
            icon: "moon"
            title: "Night Mode"
            subtitle: NightLight.on ? "Enabled" : "Disabled"
            active: NightLight.on
            onClicked: NightLight.toggle()
        }

        ControlTile {
            width: 151; height: 48
            icon: "game"
            title: "Game Mode"
            subtitle: GameMode.on ? "Enabled" : "Disabled"
            active: GameMode.on
            onClicked: GameMode.toggle()
        }

        ControlTile {
            width: 151; height: 48
            icon: "focus"
            title: "Do Not Disturb"
            subtitle: NotifCenter.dnd ? NotifCenter.dndText : "Off"
            active: NotifCenter.dnd
            onClicked: NotifCenter.toggleDnd()
        }

        ControlTile {
            width: 151; height: 48
            icon: "screen"
            title: "Screens"
            subtitle: "Mirror, position"
            active: false
            onClicked: root.openPanel("monitors")
        }
    }

    // ---------- Sliders ----------
    Column {
        x: 14; y: 130
        spacing: 10

        SliderBar {
            id: lightSlider
            track: Theme.surfaceSoft
            width: 312; height: 26
            value: Brightness.percent
            icon: "sun"
            enabled: Brightness.available
            showMore: true
            onMoved: v => Brightness.setPercent(v)
            onMore: root.openPanel("display")
        }

        SliderBar {
            id: soundSlider
            track: Theme.surfaceSoft
            width: 312; height: 26
            value: Math.min(1, Audio.volume)
            icon: "volume"
            iconLevel: Audio.muted ? 0 : (Audio.volume > 0.5 ? 2 : 1)
            showMore: true
            onMoved: v => Audio.setVolume(v)
            onMore: root.openPanel("sound")
        }

        SliderBar {
            id: micSlider
            track: Theme.surfaceSoft
            width: 312; height: 26
            value: Math.min(1, Audio.micVolume)
            icon: "mic"
            iconLevel: Audio.micMuted ? 0 : 2
            enabled: Audio.micReady
            showMore: true
            onMoved: v => Audio.setMicVolume(v)
            onMore: root.openPanel("sound")
        }
    }

    // ---------- Meters ----------
    Rectangle {
        x: 14; y: 248
        width: 312; height: 82
        radius: 20
        color: Theme.surfaceSoft

        Repeater {
            model: ["cpu", "ram", "bat"]

            delegate: Item {
                id: row

                required property string modelData
                required property int index

                readonly property real val: index === 0 ? SysStats.cpu : (index === 1 ? SysStats.ram : Battery.percent)
                readonly property color tone: index === 0 ? Theme.accent : (index === 1 ? Theme.note : Battery.tone)

                x: 16; y: 10 + index * 22
                width: parent.width - 32
                height: 20

                Glyph {
                    visible: row.modelData !== "bat"
                    anchors.verticalCenter: parent.verticalCenter
                    kind: row.modelData
                    size: 14
                    color: Theme.foreground
                }

                BatteryIcon {
                    visible: row.modelData === "bat"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 8
                    percent: Battery.percent
                    charging: Battery.charging
                    outline: Theme.foreground
                    fillColor: Battery.tone
                }

                Rectangle {
                    x: 26
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 26 - 40
                    height: 8
                    radius: 4
                    color: Theme.island

                    Rectangle {
                        width: Math.max(parent.height, parent.width * Math.min(1, row.val))
                        height: parent.height
                        radius: 4
                        color: row.tone
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(row.val * 100) + "%"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
