import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.pages

// "Dashboard" style: one pill that grows.
//   closed -> workspaces · clock · wifi + battery
//   peek   -> (mouse over) clock and date, workspaces, music card, status
//   open   -> (click) the full dashboard; the dots switch pages (also Alt+1/2/3)
Rectangle {
    id: root

    property string screenName: ""
    property string mode: "closed"          // closed | peek | open
    property string page: "dash"            // dash | tools | monitors | wifi | bluetooth | sound | display

    readonly property var pager: ["dash", "tools", "monitors"]
    readonly property int pageIndex: pager.indexOf(page)
    readonly property bool inPager: pageIndex >= 0

    // Same interface as ControlIsland, so the bar can drive both
    readonly property bool expanded: mode === "open"
    readonly property bool needsKeyboard: expanded && page === "wifi" && wifiPage.needsKeyboard
    readonly property bool busy: dashPage.dragging || displayPage.dragging || soundPage.dragging
                                 || toolsDash.dragging || monitorsDash.dragging || needsKeyboard
    readonly property bool hovered: hover.hovered

    readonly property int headerH: 34
    readonly property int baseW: 250

    // What the closed pill shows next to the clock (the pill stretches to make room)
    property bool hot: false
    readonly property bool timerOn: Chrono.timerRunning || Chrono.timerDone || Chrono.swRunning
    readonly property bool musicOn: Media.active && Media.playing
    readonly property string extra: timerOn ? "timer" : (musicOn ? "music" : (hot ? "stats" : ""))
    readonly property int closedW: baseW + (extra === "" ? 0 : 120)

    // Attached version: when the volume or brightness changes, the closed bar itself becomes the OSD
    readonly property bool osdOn: attached && OsdState.shown && mode === "closed"
    readonly property int osdW: 320

    // Border flash (workspace change, new notification)
    property bool flash: false
    function pulse() { flash = true; flashTimer.restart() }
    Timer { id: flashTimer; interval: 650; onTriggered: root.flash = false }
    onActiveIdChanged: pulse()
    Connections {
        target: NotifCenter
        function onUnreadChanged() { if (NotifCenter.unread) root.pulse() }
    }

    // Hysteresis: the CPU/RAM chip does not flicker around the threshold
    function updateHot() {
        const high = SysStats.cpu > 0.85 || SysStats.ram > 0.9
        const calm = SysStats.cpu < 0.70 && SysStats.ram < 0.80
        if (high) hot = true
        else if (calm) hot = false
    }
    Connections {
        target: SysStats
        function onCpuChanged() { root.updateHot() }
        function onRamChanged() { root.updateHot() }
    }

    // Live readings for the closed chip and the peek meters
    Component.onCompleted: SysStats.users++
    Component.onDestruction: SysStats.users--
    readonly property int peekW: 540
    readonly property bool attached: Style.dashAttached
    readonly property bool peekMusic: attached && Media.active   // attached version: the song shows up in the bar of the mouse-over
    readonly property int peekH: attached ? (peekMusic ? 88 : 56) : 124
    readonly property int dashW: 860
    readonly property int dashH: headerH + 308 + 14
    readonly property bool wide: page === "dash" || page === "tools" || page === "monitors"
    readonly property int cardW: wide ? dashW : 360
    readonly property int cardH: wide ? dashH : 440

    // Page contents appear a moment after the pill starts growing, so opening is never held up by them
    property bool contentOn: false
    Timer { id: contentTimer; interval: 150; onTriggered: root.contentOn = (root.mode === "open") }

    function close() { mode = "closed" }

    function gotoPage(i) {
        if (i < 0 || i >= pager.length) return
        page = pager[i]
    }

    width: mode === "open" ? cardW : (mode === "peek" ? peekW : (osdOn ? osdW : closedW))
    height: mode === "open" ? cardH : (mode === "peek" ? peekH : Theme.islandHeight)
    // Colors of the edge (the "Attached" version draws it with AttachedShape, from the bar)
    readonly property color edgeColor: flash ? Theme.accent
                  : (musicOn ? Theme.mix(Theme.border, Theme.accent, 0.5) : Theme.border)
    readonly property real edgeWidth: flash ? 2 : 1
    readonly property real corner: mode === "open" ? 26 : 18

    radius: attached ? corner : Math.min(26, height / 2)
    color: attached ? "transparent" : Theme.island
    border.width: attached ? 0 : edgeWidth
    border.color: edgeColor
    clip: true

    Behavior on border.color { ColorAnimation { duration: 260 } }

    // Elastic: a springy settle when it opens or changes size, a small rebound when it closes
    Behavior on width {
        NumberAnimation {
            duration: root.mode === "closed" ? 460 : 720
            easing.type: root.mode === "closed" ? Easing.OutBack : Easing.OutElastic
            easing.overshoot: 1.6
            easing.amplitude: 1.0
            easing.period: 0.75
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: root.mode === "closed" ? 320 : 640
            easing.type: root.mode === "closed" ? Easing.OutCubic : Easing.OutElastic
            easing.amplitude: 1.0
            easing.period: 0.8
        }
    }


    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property var dots: Compositor.dotsFor(screenName)
    readonly property int activeId: Compositor.activeIdFor(screenName)

    onModeChanged: {
        UiState.controlOpen = mode === "open"
        if (mode === "open") contentTimer.restart()
        else { contentTimer.stop(); contentOn = false }
        if (mode === "open") {
            resetTimer.stop()
            Brightness.refresh()
            NotifCenter.unread = false
        } else if (mode === "closed") {
            resetTimer.restart()
        }
    }

    Timer {
        id: resetTimer
        interval: 350
        onTriggered: root.page = "dash"
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop()
                if (root.mode === "closed") root.mode = "peek"
            } else {
                collapseTimer.restart()
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 300
        onTriggered: {
            if (root.busy) restart()
            else root.mode = "closed"
        }
    }

    // A click on the card opens the dashboard
    MouseArea {
        anchors.fill: parent
        enabled: root.mode === "peek"
        cursorShape: Qt.PointingHandCursor
        onClicked: root.mode = "open"
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (root.mode !== "open" || wheelCool.running || !root.inPager) return
            const next = root.pageIndex + (event.angleDelta.y < 0 ? 1 : -1)
            if (next < 0 || next >= root.pager.length) return
            root.gotoPage(next)
            wheelCool.start()
        }
    }

    Timer {
        id: wheelCool
        interval: 450
    }

    function two(n) { return (n < 10 ? "0" : "") + n }

    // First note of today that has not passed yet
    readonly property var nextEvent: {
        const d = clock.date
        const hm = two(d.getHours()) + ":" + two(d.getMinutes())
        const l = Notes.forDate(Notes.keyOf(d))
        for (let i = 0; i < l.length; i++)
            if (!l[i].time || l[i].time >= hm) return l[i]
        return null
    }

    // ---------- Attached version: the bar turned into the volume / brightness OSD ----------
    Item {
        id: osdView
        width: root.osdW
        height: Theme.islandHeight
        opacity: root.osdOn ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.osdOn ? 220 : 90 } }

        SliderBar {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 62
            anchors.verticalCenter: parent.verticalCenter
            height: 24
            implicitHeight: 24
            enabled: false
            value: OsdState.value
            icon: OsdState.icon
            iconLevel: OsdState.iconLevel
            track: Theme.mix(Theme.island, Theme.foreground, 0.14)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(OsdState.value * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }
    }

    // ---------- Closed: workspaces · clock · wifi + battery ----------
    Item {
        id: closedView
        width: root.closedW
        height: Theme.islandHeight
        opacity: (root.mode === "closed" && !root.osdOn) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: (root.mode === "closed" && !root.osdOn) ? 200 : 90 } }

        Row {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: Math.min(root.dots.length, 6)

                delegate: Rectangle {
                    required property int index
                    readonly property bool active: root.dots[index].id === root.activeId

                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? 14 : 6
                    height: 6
                    radius: 3
                    color: active ? Theme.accent
                           : (root.dots[index].occupied ? Theme.foreground : Theme.mix(Theme.island, Theme.foreground, 0.22))
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
        }

        Row {
            // The clock stays where it is while the pill stretches to its right
            x: root.baseW / 2 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                visible: Capture.recording
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7
                radius: 3.5
                color: Capture.paused ? Theme.muted : Theme.danger
            }

            Text {
                text: Capture.recording ? Capture.timeText
                                        : Qt.formatDateTime(clock.date, Settings.timeFormat)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }

        // Extra slot: timer · music · CPU/RAM when they are high
        Item {
            id: extraSlot
            x: root.baseW / 2 + 40
            width: root.closedW - x - 70
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            opacity: root.extra !== "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            // Timer / stopwatch
            Row {
                visible: root.extra === "timer"
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: Chrono.timerRunning || Chrono.timerDone ? "hourglass" : "stopwatch"
                    size: 13
                    color: Chrono.timerDone ? Theme.danger : Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Chrono.timerRunning || Chrono.timerDone ? Chrono.timerText : Chrono.swText
                    color: Chrono.timerDone ? Theme.danger : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            // Music: small cover + scrolling title
            Row {
                visible: root.extra === "music"
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                ClippingRectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20
                    radius: 7
                    color: Theme.surfaceSoft

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(48, 48)
                    }
                }

                Item {
                    id: marquee
                    anchors.verticalCenter: parent.verticalCenter
                    width: extraSlot.width - 27
                    height: 18
                    clip: true

                    Text {
                        id: marqueeText
                        anchors.verticalCenter: parent.verticalCenter
                        text: Media.title + (Media.artist !== "" ? "  ·  " + Media.artist : "")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11

                        readonly property real overflow: Math.max(0, implicitWidth - marquee.width)

                        SequentialAnimation on x {
                            running: marqueeText.overflow > 0 && root.extra === "music" && root.mode === "closed"
                            loops: Animation.Infinite
                            PropertyAction { value: 0 }
                            PauseAnimation { duration: 1800 }
                            NumberAnimation {
                                to: -marqueeText.overflow
                                duration: Math.max(600, marqueeText.overflow * 35)
                                easing.type: Easing.InOutSine
                            }
                            PauseAnimation { duration: 1400 }
                            onRunningChanged: if (!running) marqueeText.x = 0
                        }
                    }
                }
            }

            // CPU or RAM, whichever is higher
            Row {
                visible: root.extra === "stats"
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                readonly property bool cpuHigher: SysStats.cpu >= SysStats.ram
                readonly property real val: cpuHigher ? SysStats.cpu : SysStats.ram

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: parent.cpuHigher ? "cpu" : "ram"
                    size: 13
                    color: parent.val > 0.9 ? Theme.danger : Theme.accent
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 5
                    radius: 2.5
                    color: Theme.mix(Theme.island, Theme.foreground, 0.18)

                    Rectangle {
                        width: Math.max(5, parent.width * parent.parent.val)
                        height: parent.height
                        radius: 2.5
                        color: parent.parent.val > 0.9 ? Theme.danger : Theme.accent
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(parent.val * 100) + "%"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: "wifi"
                level: Network.level
                size: 14
                color: Network.wifiOn ? (Network.connected ? Theme.accent : Theme.foreground) : Theme.muted
            }

            BatteryIcon {
                visible: Battery.present
                anchors.verticalCenter: parent.verticalCenter
                percent: Battery.percent
                charging: Battery.charging
                outline: Battery.tone
                fillColor: Battery.tone
            }
        }
    }

    // ---------- Peek: card with the main information ----------
    Item {
        id: peekView
        width: root.peekW
        height: root.peekH
        opacity: (root.mode === "peek" && !root.attached) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "peek" ? 220 : 80 } }

        Row {
            y: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                text: Qt.formatDateTime(clock.date, Settings.timeFormat)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 3
                text: Qt.locale("en_US").toString(clock.date, "ddd, MMM d")
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }

        // Next appointment of today (from the calendar notes)
        Text {
            x: 30; y: 20
            width: 150
            visible: root.nextEvent !== null
            text: root.nextEvent ? ((root.nextEvent.time || "Today") + " · " + root.nextEvent.title) : ""
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // Live meters: CPU · RAM · volume
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 30
            y: 10
            spacing: 9

            Repeater {
                model: ["cpu", "ram", "volume"]

                delegate: Item {
                    id: pm

                    required property string modelData
                    required property int index

                    readonly property real val: index === 0 ? SysStats.cpu : (index === 1 ? SysStats.ram : Math.min(1, Audio.volume))
                    readonly property color tone: index === 0 ? Theme.accent : (index === 1 ? Theme.note : Theme.foreground)

                    width: 14; height: 36

                    Rectangle {
                        x: 4; y: 0
                        width: 6; height: 24
                        radius: 3
                        color: Theme.mix(Theme.island, Theme.foreground, 0.16)

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(width, parent.height * pm.val)
                            radius: 3
                            color: pm.tone
                            opacity: pm.index === 2 && Audio.muted ? 0.35 : 1
                            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }

                    Glyph {
                        x: 2; y: 26
                        kind: pm.modelData
                        level: Audio.muted ? 0 : 2
                        size: 10
                        color: Theme.muted
                    }
                }
            }
        }

        // Workspaces: vertical pills, the active one is taller
        Row {
            x: 30
            y: 54
            height: 56
            spacing: 6

            Repeater {
                model: Math.min(root.dots.length, 8)

                delegate: Rectangle {
                    required property int index
                    readonly property bool active: root.dots[index].id === root.activeId

                    anchors.verticalCenter: parent.verticalCenter
                    width: 9
                    height: active ? 30 : 16
                    radius: 4.5
                    color: active ? Theme.accent
                           : (root.dots[index].occupied ? Theme.foreground : Theme.mix(Theme.island, Theme.foreground, 0.22))
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
        }

        // Music (blurred cover as background)
        ClippingRectangle {
            x: (parent.width - width) / 2
            y: 54
            width: 300; height: 56
            radius: 18
            color: Theme.surfaceSoft

            Image {
                id: peekBlurSrc
                anchors.fill: parent
                source: Media.artUrl
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(96, 96)
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: peekBlurSrc
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

            ClippingRectangle {
                x: 8; y: 8
                width: 40; height: 40
                radius: 12
                color: Theme.island
                visible: Media.active

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(96, 96)
                }
            }

            Column {
                x: Media.active ? 58 : 16
                anchors.verticalCenter: parent.verticalCenter
                width: 130
                spacing: 1

                Text {
                    width: parent.width
                    text: Media.active ? (Media.title || "No title") : "Nothing playing"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: Media.active
                    text: Media.artist
                    color: Theme.foreground
                    opacity: 0.75
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            // Live audio spectrum (progress dots if cava is missing)
            Spectrum {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 70; height: 30
                visible: Media.active
            }
        }

        // Status: wifi and battery
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 28
            y: 70
            spacing: 12

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: "wifi"
                level: Network.level
                size: 18
                color: Network.wifiOn ? (Network.connected ? Theme.accent : Theme.foreground) : Theme.muted
            }

            BatteryIcon {
                visible: Battery.present
                anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 14
                percent: Battery.percent
                charging: Battery.charging
                outline: Battery.tone
                fillColor: Battery.tone
            }
        }
    }

    // ---------- Peek: the attached bar, taller: Desktop · dots | clock + date | notifications · wifi + battery ----------
    Item {
        id: peekAttached
        width: root.peekW
        height: root.peekH
        opacity: (root.mode === "peek" && root.attached) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "peek" ? 220 : 80 } }

        // left: workspace name, and the dots below it
        Column {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Row {
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: Theme.accent
                }
                Text {
                    text: "Desktop " + root.activeId
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Row {
                spacing: 4
                Repeater {
                    model: Math.min(root.dots.length, 6)
                    delegate: Rectangle {
                        required property int index
                        readonly property bool active: root.dots[index].id === root.activeId
                        width: active ? 18 : 7
                        height: 7
                        radius: 3.5
                        color: active ? Theme.accent
                               : (root.dots[index].occupied ? Theme.foreground : Theme.mix(Theme.island, Theme.foreground, 0.22))
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // center: clock and date, and the song below it (only while there is a player)
        Column {
            anchors.centerIn: parent
            spacing: 7

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, Settings.timeFormat)
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd, MMM d")
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            Item {
                visible: root.peekMusic
                anchors.horizontalCenter: parent.horizontalCenter
                width: 250
                height: 26

                ClippingRectangle {
                    id: peekCover
                    x: 0
                    anchors.verticalCenter: titleLine.verticalCenter
                    width: 20; height: 20
                    radius: 6
                    color: Theme.surfaceSoft

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(48, 48)
                    }
                }

                Text {
                    id: titleLine
                    x: 28
                    y: 0
                    width: parent.width - 28
                    elide: Text.ElideRight
                    text: Media.title + (Media.artist !== "" ? "  ·  " + Media.artist : "")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Rectangle {   // progress
                    x: 28
                    y: titleLine.height + 5
                    width: parent.width - 28
                    height: 3
                    radius: 1.5
                    color: Theme.mix(Theme.island, Theme.foreground, 0.18)

                    Rectangle {
                        width: Math.max(3, parent.width * Media.progress)
                        height: parent.height
                        radius: 1.5
                        color: Theme.accent
                    }
                }
            }
        }

        // keeps the progress bar moving while the bar is open
        FrameAnimation {
            running: root.mode === "peek" && root.peekMusic && Media.playing
            onTriggered: if (Media.player) Media.player.positionChanged()
        }

        // right: notifications, and wifi + battery below
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Row {
                anchors.right: parent.right
                spacing: 7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotifCenter.count > 0 ? NotifCenter.count + " new" : "All caught up"
                    color: NotifCenter.count > 0 ? Theme.accent : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "bell"
                    size: 13
                    color: NotifCenter.count > 0 ? Theme.accent : Theme.muted
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 8
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "wifi"
                    level: Network.level
                    size: 13
                    color: Network.wifiOn ? (Network.connected ? Theme.accent : Theme.foreground) : Theme.muted
                }
                BatteryIcon {
                    visible: Battery.present
                    anchors.verticalCenter: parent.verticalCenter
                    percent: Battery.percent
                    charging: Battery.charging
                    outline: Battery.tone
                    fillColor: Battery.tone
                }
            }
        }
    }


    // ---------- Open: dots to switch pages ----------
    Item {
        x: 0; y: 0
        width: root.cardW
        height: root.headerH
        z: 50
        opacity: (root.contentOn && root.inPager) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            spacing: 5

            Repeater {
                model: root.pager.length

                delegate: Rectangle {
                    id: dot

                    required property int index

                    width: root.pageIndex === index ? 16 : 5
                    height: 5
                    radius: 2.5
                    color: root.pageIndex === index ? Theme.accent : Theme.mix(Theme.island, Theme.foreground, 0.30)
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.gotoPage(dot.index)
                    }
                }
            }
        }
    }

    // ---------- Pages (cross-fade) ----------
    DashPage {
        id: dashPage
        x: 0; y: root.headerH
        opacity: (root.contentOn && root.page === "dash") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onOpenPage: name => root.page = name
        onPasted: root.mode = "closed"
    }

    ToolsDash {
        id: toolsDash
        x: 0; y: root.headerH
        opacity: (root.contentOn && root.page === "tools") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onPasted: root.mode = "closed"
    }

    MonitorsDash {
        id: monitorsDash
        x: 0; y: root.headerH
        opacity: (root.contentOn && root.page === "monitors") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onOpenPage: name => root.page = name
    }

    WifiPage {
        id: wifiPage
        opacity: (root.contentOn && root.page === "wifi") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "dash"
    }

    BluetoothPage {
        id: btPage
        opacity: (root.contentOn && root.page === "bluetooth") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "dash"
    }

    DisplayPage {
        id: displayPage
        opacity: (root.contentOn && root.page === "display") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "dash"
    }

    SoundPage {
        id: soundPage
        opacity: (root.contentOn && root.page === "sound") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "dash"
    }
}
