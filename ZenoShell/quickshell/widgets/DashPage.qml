import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Bluetooth
import qs.theme
import qs.services

// Dashboard (style "Dashboard", click state): music · tiles · sliders · calendar · notifications · clipboard · meters
Item {
    id: root

    signal openPage(string name)
    signal pasted()
    property bool dragging: soundSlider.pressed || lightSlider.pressed || micSlider.pressed || dayMode

    readonly property var bt: Bluetooth.defaultAdapter

    width: 860
    height: 308

    // Notes of a day (click on a day): they open in the calendar's own space
    property bool dayMode: false
    property int dayYear: 2000
    property int dayMonth: 0
    property int dayDay: 1

    // The CPU / RAM bars need live readings while the dashboard is visible
    property bool counted: false

    // Calendar shown by the arrows
    property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    function shiftMonth(d) {
        let m = viewMonth + d
        let y = viewYear
        if (m < 0) { m = 11; y-- }
        else if (m > 11) { m = 0; y++ }
        viewMonth = m
        viewYear = y
    }

    onVisibleChanged: {
        ClipHist.active = visible
        if (visible && !counted) { SysStats.users++; counted = true }
        else if (!visible && counted) { SysStats.users--; counted = false }
        if (!visible) dayMode = false
        if (visible) {
            ClipHist.refresh()
            today = new Date()
            viewYear = today.getFullYear()
            viewMonth = today.getMonth()
        }
    }

    // ---------- Music (blurred cover as background) ----------
    ClippingRectangle {
        id: music

        x: 14; y: 0
        width: 176; height: root.height
        radius: 24
        color: Theme.surfaceSoft

        Image {
            id: blurSrc
            anchors.fill: parent
            source: Media.artUrl
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(96, 96)
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: blurSrc
            visible: Media.active && Media.artUrl !== ""
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.3
        }

        Rectangle {
            anchors.fill: parent
            visible: Media.active && Media.artUrl !== ""
            color: Theme.scrim
        }

        // The record: cover in a circle with a ring
        Rectangle {
            id: disc
            x: (parent.width - width) / 2
            y: 20
            width: 124; height: 124
            radius: 62
            color: Theme.island
            border.width: 3
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)

            ClippingRectangle {
                anchors.centerIn: parent
                width: parent.width - 14
                height: width
                radius: width / 2
                color: Theme.accent

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    visible: Media.active && Media.artUrl !== ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(256, 256)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 16; height: 16
                    radius: 8
                    color: Theme.island
                    opacity: 0.9
                }
            }

            RotationAnimator on rotation {
                from: 0; to: 360
                duration: 14000
                loops: Animation.Infinite
                running: Media.playing && root.visible
            }
        }

        Text {
            x: 10; y: 154
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            text: Media.active ? (Media.title || "No title") : "Nothing Playing"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            x: 10; y: 175
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            text: Media.active ? Media.artist : "Enjoy the silence"
            color: Theme.foreground
            opacity: 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Row {
            y: 204
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            MediaButton { kind: "prev"; enabled: Media.canPrevious; onClicked: Media.previous() }
            MediaButton { kind: Media.playing ? "pause" : "play"; highlighted: true; enabled: Media.canToggle; onClicked: Media.toggle() }
            MediaButton { kind: "next"; enabled: Media.canNext; onClicked: Media.next() }
        }

        // Progress bar (click = seek)
        Item {
            x: 16; y: 252
            width: parent.width - 32
            height: 12

            Rectangle {
                id: seekTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.25)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: seekTrack.width * Media.progress
                height: 4
                radius: 2
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                enabled: Media.canSeek
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => Media.seekTo(mouse.x / width)
            }
        }

        Text {
            x: 16; y: 270
            text: Media.active ? Media.fmt(Media.position) : "--:--"
            color: Theme.foreground
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 270
            text: Media.active ? Media.fmt(Media.length) : "--:--"
            color: Theme.foreground
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    // ---------- Tiles ----------
    Row {
        x: 202; y: 0
        spacing: 8

        ControlTile {
            width: 133; height: 48
            icon: "wifi"
            iconLevel: Network.level
            title: "Wi-Fi"
            subtitle: !Network.wifiOn ? "Off" : (Network.connected ? Network.ssid : "Not connected")
            active: Network.wifiOn
            onClicked: root.openPage("wifi")

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: Theme.muted
                font.pixelSize: 16
            }
        }

        ControlTile {
            width: 133; height: 48
            icon: "bluetooth"
            title: "Bluetooth"
            subtitle: root.bt ? (root.bt.enabled ? "On" : "Off") : "Unavailable"
            active: root.bt ? root.bt.enabled : false
            onClicked: root.openPage("bluetooth")

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: Theme.muted
                font.pixelSize: 16
            }
        }

        ControlTile {
            width: 133; height: 48
            icon: "moon"
            title: "Night Mode"
            subtitle: NightLight.on ? "Enabled" : "Disabled"
            active: NightLight.on
            onClicked: NightLight.toggle()
        }

        ControlTile {
            width: 133; height: 48
            icon: "game"
            title: "Game Mode"
            subtitle: GameMode.on ? "Enabled" : "Disabled"
            active: GameMode.on
            onClicked: GameMode.toggle()
        }
    }

    // ---------- Sliders ----------
    Row {
        x: 202; y: 58
        spacing: 10

        SliderBar {
            id: lightSlider
            track: Theme.surfaceSoft
            width: 178; height: 26
            value: Brightness.percent
            icon: "sun"
            enabled: Brightness.available
            showMore: true
            onMoved: v => Brightness.setPercent(v)
            onMore: root.openPage("display")
        }

        SliderBar {
            id: soundSlider
            track: Theme.surfaceSoft
            width: 178; height: 26
            value: Math.min(1, Audio.volume)
            icon: "volume"
            iconLevel: Audio.muted ? 0 : (Audio.volume > 0.5 ? 2 : 1)
            showMore: true
            onMoved: v => Audio.setVolume(v)
            onMore: root.openPage("sound")
        }

        SliderBar {
            id: micSlider
            track: Theme.surfaceSoft
            width: 178; height: 26
            value: Math.min(1, Audio.micVolume)
            icon: "mic"
            iconLevel: Audio.micMuted ? 0 : 2
            enabled: Audio.micReady
            showMore: true
            onMoved: v => Audio.setMicVolume(v)
            onMore: root.openPage("sound")
        }
    }

    // ---------- Calendar (a click on a day opens its notes in the same space) ----------
    Item {
        x: 202; y: 96
        width: 196; height: 212

        DayNotes {
            id: dayNotes
            anchors.fill: parent
            visible: root.dayMode
            year: root.dayYear
            month: root.dayMonth
            day: root.dayDay
            onCloseRequested: root.dayMode = false
            onVisibleChanged: if (visible) reset()
        }

        Row {
            visible: !root.dayMode
            width: parent.width
            height: 24

            NavButton {
                width: 24; height: 24
                label: "‹"
                onClicked: root.shiftMonth(-1)
            }

            Text {
                width: parent.width - 48
                height: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Qt.locale("en_US").monthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

            NavButton {
                width: 24; height: 24
                label: "›"
                onClicked: root.shiftMonth(1)
            }
        }

        MonthGrid {
            y: 30
            visible: !root.dayMode
            cellW: 28
            cellH: 25
            year: root.viewYear
            month: root.viewMonth
            today: root.today
            onDayClicked: d => {
                root.dayYear = d.getFullYear()
                root.dayMonth = d.getMonth()
                root.dayDay = d.getDate()
                root.dayMode = true
            }
        }
    }

    // ---------- Notifications (half of the free space) ----------
    Rectangle {
        x: 410; y: 96
        width: 170; height: 212
        radius: 20
        color: Theme.surfaceSoft

        Text {
            x: 14; y: 11
            text: "Notifications"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        // Do not disturb
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: NotifCenter.count > 0 ? 40 : 10
            y: 6
            width: 22; height: 22
            radius: 11
            color: NotifCenter.dnd ? Theme.accent : (dndMouse.containsMouse ? Theme.islandHover : Theme.island)
            Behavior on color { ColorAnimation { duration: 120 } }

            Glyph {
                anchors.centerIn: parent
                kind: "focus"
                size: 12
                color: NotifCenter.dnd ? Theme.island : Theme.foreground
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotifCenter.toggleDnd()
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 11
            visible: NotifCenter.count > 0
            text: "Clear"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: NotifCenter.clearAll()
            }
        }

        Text {
            x: 0; y: 34
            width: parent.width
            height: parent.height - 34
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: NotifCenter.count === 0
            text: NotifCenter.dnd ? "Do not disturb\n" + NotifCenter.dndText : "No notifications"
            color: Theme.muted
            opacity: 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        ListView {
            x: 8; y: 34
            width: parent.width - 16
            height: parent.height - 34 - 8
            spacing: 5
            clip: true
            model: NotifCenter.list

            delegate: Rectangle {
                id: nItem

                required property var modelData

                width: ListView.view.width
                height: nText.implicitHeight + 14
                radius: 12
                color: Theme.island

                Column {
                    id: nText
                    x: 10; y: 7
                    width: parent.width - 20 - 14
                    spacing: 1

                    Text {
                        width: parent.width
                        text: nItem.modelData.appName
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: nItem.modelData.summary
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: nItem.modelData.body
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        textFormat: Text.StyledText
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 4
                    text: "×"
                    color: Theme.muted
                    font.pixelSize: 15

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nItem.modelData.dismiss()
                    }
                }
            }
        }
    }

    // ---------- Clipboard (the other half) ----------
    ClipCard {
        x: 588; y: 96
        width: 170; height: 212
        onPasted: root.pasted()
    }

    // ---------- Meters: CPU · RAM · battery ----------
    Rectangle {
        x: 770; y: 0
        width: 76; height: root.height
        radius: 24
        color: Theme.surfaceSoft

        Repeater {
            model: ["cpu", "ram", "bat"]

            delegate: Item {
                id: meter

                required property string modelData
                required property int index

                // Read directly from the services, so the bars follow them live
                readonly property real val: index === 0 ? SysStats.cpu : (index === 1 ? SysStats.ram : Battery.percent)
                readonly property color tone: index === 0 ? Theme.accent : (index === 1 ? Theme.note : Battery.tone)

                x: 8 + index * 20
                y: 14
                width: 20
                height: root.height - 28

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(meter.val * 100)
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                Rectangle {
                    id: track
                    x: 2; y: 16
                    width: 16
                    height: parent.height - 16 - 30
                    radius: 8
                    color: Theme.island

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(width, parent.height * Math.min(1, meter.val))
                        radius: width / 2
                        color: meter.tone
                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }

                Glyph {
                    visible: meter.modelData !== "bat"
                    x: (parent.width - width) / 2
                    y: parent.height - 22
                    kind: meter.modelData
                    size: 14
                    color: Theme.foreground
                }

                BatteryIcon {
                    visible: meter.modelData === "bat"
                    x: (parent.width - width) / 2 - 1
                    y: parent.height - 18
                    width: 18; height: 9
                    percent: Battery.percent
                    charging: Battery.charging
                    outline: Theme.foreground
                    fillColor: Battery.tone
                }
            }
        }
    }
}
