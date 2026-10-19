import QtQuick
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The media player that opens over the dock's media key (Dock.qml). Pure UI on
// top of a MediaSource (MediaSource.qml) given as `source`.
//
//   [ cover ]  title (2 lines)
//   [       ]  artist
//   [       ]  (player name)
//   ----o------------------   <- the lane: click or drag to seek, wheel = 5 s
//   1:23                3:45
//   [-10]  [prev]  [PLAY]  [next]  [+10]
//
// While you hold the playhead a small time chip floats over it; while you only
// hover the lane, the left time shows the time under the pointer.
DockCard {
    id: root

    property var source: null

    readonly property var player: root.source ? root.source.player : null
    readonly property bool playing: root.source ? root.source.playing : false
    readonly property bool hasLength: root.player !== null && root.player.lengthSupported === true
                                      && root.player.length > 0

    readonly property real artSize: 92
    readonly property real laneGap: 12
    readonly property real laneH: 22
    readonly property real timesH: 14
    readonly property real keysH: 40

    readonly property real lanesBlock: root.hasLength ? (root.laneGap + root.laneH + 2 + root.timesH) : 0
    readonly property real keysY: root.artSize + root.lanesBlock + 10

    contentWidth: 340
    contentHeight: root.keysY + root.keysH

    Behavior on contentHeight {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec))
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        const s = sec % 60
        return h > 0 ? (h + ":" + ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2))
                     : (m + ":" + ("0" + s).slice(-2))
    }

    // Jump `sec` seconds from where the player is now (negative = back).
    function seekBy(sec) {
        if (!lane.seekable)
            return
        root.player.positionChanged()
        const target = Math.max(0, Math.min(lane.length, root.player.position + sec))
        root.player.position = target
        lane.shownFrac = lane.length > 0 ? target / lane.length : 0
    }

    // The player doesn't announce its position; ask for it while the card is open.
    Timer {
        interval: 400
        repeat: true
        triggeredOnStart: true
        running: root.open && root.player !== null && root.player.positionSupported
        onTriggered: {
            if (root.playing)
                root.player.positionChanged()
            lane.readPosition()
        }
    }

    Connections {
        target: root.source
        ignoreUnknownSignals: true

        function onTitleChanged() { lane.readPosition() }
    }

    // ===== cover =====
    Rectangle {
        id: art
        x: root.pad
        y: root.pad
        width: root.artSize
        height: root.artSize
        radius: 16
        color: Theme.surfaceDivider
        border.width: 3
        border.color: Theme.line
        antialiasing: true

        Image {
            id: cover
            anchors.fill: parent
            anchors.margins: 3
            visible: status === Image.Ready
            asynchronous: true
            smooth: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(184, 184)
            source: root.source ? root.source.artUrl : ""
            // dims a little while paused, like a record that stopped
            opacity: root.playing || !root.source || !root.source.present ? 1 : 0.65

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            name: "genres"
            size: 38
        }
    }

    // ===== title, artist, player =====
    Item {
        id: titleBox
        x: root.pad + root.artSize + 14
        y: root.pad
        width: root.contentWidth - root.artSize - 14
        height: root.artSize

        Column {
            anchors.top: parent.top
            width: parent.width
            spacing: 2

            Text {
                width: parent.width
                text: root.source && root.source.present ? root.source.title : "Nothing playing"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.source ? root.source.artist : ""
                visible: text !== ""
                color: Theme.inkSub
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        // which app is playing
        Rectangle {
            id: whoChip
            readonly property string who: root.player && root.player.identity ? root.player.identity : ""
            // room left for the name once the icon, the gap and the padding are taken off
            readonly property real maxTextW: titleBox.width - 16 - 18
            visible: who !== ""
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: 22
            width: Math.min(titleBox.width, whoRow.implicitWidth + 16)
            radius: 8
            color: Theme.surfaceDivider
            antialiasing: true

            Row {
                id: whoRow
                anchors.centerIn: parent
                spacing: 4

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.playing ? "graphic_eq" : "pause"
                    size: 14
                    color: Theme.inkSub
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, whoChip.maxTextW)
                    elide: Text.ElideRight
                    text: whoChip.who
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }
    }

    // ===== the lane: click or drag to seek =====
    Item {
        id: lane
        visible: root.hasLength
        x: root.pad
        y: root.pad + root.artSize + root.laneGap
        width: root.contentWidth
        height: root.laneH

        readonly property real length: root.player && root.player.lengthSupported ? Math.max(0, root.player.length) : 0
        readonly property bool seekable: root.player !== null && root.player.canSeek && root.player.positionSupported && length > 0
        property real shownFrac: 0
        property bool dragging: false
        property real dragFrac: 0
        property real hoverFrac: 0
        readonly property bool previewing: dragging || laneArea.containsMouse
        readonly property real frac: dragging ? dragFrac : shownFrac

        function readPosition() {
            if (!root.player || length <= 0 || !root.player.positionSupported) {
                shownFrac = 0
                return
            }
            const f = Math.max(0, Math.min(1, root.player.position / length))
            // Players report their position a little unevenly. While it plays the
            // head only goes forward for that; a real seek or a new track still moves it.
            if (root.playing && !dragging && (shownFrac - f) * length > 0 && (shownFrac - f) * length < 2.5)
                return
            shownFrac = f
        }

        Item {
            id: track
            x: 4
            width: parent.width - 8
            height: parent.height

            readonly property real headSize: 13
            readonly property real headX: Math.min(width - headSize, Math.max(0, width * lane.frac - headSize / 2))

            opacity: lane.seekable ? 1 : 0.55

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 12
                radius: 6
                color: Theme.surfaceDivider
                border.width: 2
                border.color: Theme.line
            }

            // how much is gone
            Rectangle {
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                radius: 4
                width: Math.max(0, track.headX + track.headSize / 2 - 2)

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accentMint }
                    GradientStop { position: 1.0; color: Theme.accentCyan }
                }

                Behavior on width {
                    enabled: !lane.dragging && root.open
                    NumberAnimation { duration: 400 }
                }
            }

            // quarter marks
            Repeater {
                model: 3

                Rectangle {
                    required property int index
                    x: track.width * (index + 1) / 4 - 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 12
                    radius: 1.5
                    color: Theme.line
                    opacity: 0.35
                }
            }

            // where the pointer is, while you hover and are not dragging
            Rectangle {
                visible: laneArea.containsMouse && !lane.dragging && lane.seekable
                x: Math.max(0, Math.min(track.width - width, track.width * lane.hoverFrac - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 16
                radius: 1.5
                color: Theme.ink
                opacity: 0.5
            }

            // the playhead: a diamond that lifts while you hold it
            Rectangle {
                id: head
                x: track.headX
                y: (track.height - height) / 2 - (lane.dragging ? 3 : 0)
                width: track.headSize
                height: track.headSize
                radius: 3
                rotation: 45
                scale: lane.dragging ? 1.25 : (laneArea.containsMouse && lane.seekable ? 1.12 : 1)
                color: Theme.accentMint
                border.width: 2
                border.color: Theme.line

                Behavior on x {
                    enabled: !lane.dragging && root.open
                    NumberAnimation { duration: 400 }
                }

                Behavior on scale {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            // time chip, only while you hold the playhead
            Pill {
                visible: opacity > 0.01
                opacity: lane.dragging ? 1 : 0
                x: Math.max(-4, Math.min(track.width - width + 4, track.headX + track.headSize / 2 - width / 2))
                y: -height - 2
                z: 5
                width: chipText.implicitWidth + 18
                height: 25
                cornerRadius: 8
                borderWidth: 2
                ringWidth: 2.5
                shadowDy: 3
                fillColor: Theme.chipFill

                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: root.fmt(lane.dragFrac * lane.length)
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }

        MouseArea {
            id: laneArea
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -4
            enabled: lane.seekable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function fracAt(mx) {
                return Math.max(0, Math.min(1, (mx - track.x) / track.width))
            }

            onPressed: mouse => {
                lane.dragFrac = fracAt(mouse.x)
                lane.dragging = true
            }

            onPositionChanged: mouse => {
                lane.hoverFrac = fracAt(mouse.x)
                if (lane.dragging)
                    lane.dragFrac = lane.hoverFrac
            }

            onReleased: mouse => {
                if (!lane.dragging)
                    return
                lane.dragging = false
                lane.shownFrac = lane.dragFrac
                root.player.position = lane.dragFrac * lane.length
            }

            onCanceled: lane.dragging = false

            onWheel: wheel => root.seekBy(wheel.angleDelta.y > 0 ? 5 : -5)
        }
    }

    // ===== times =====
    Item {
        visible: root.hasLength
        x: root.pad
        y: lane.y + root.laneH + 2
        width: root.contentWidth
        height: root.timesH

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(lane.previewing ? (lane.dragging ? lane.dragFrac : lane.hoverFrac) * lane.length
                                           : lane.shownFrac * lane.length)
            color: lane.previewing ? Theme.ink : Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: lane.previewing ? Font.ExtraBold : Font.Bold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(lane.length)
            color: Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }

    // ===== keys =====
    Row {
        x: root.pad + (root.contentWidth - width) / 2
        y: root.pad + root.keysY
        spacing: 8

        Behavior on y {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: [
                { icon: "replay_10", act: "back", w: 38, h: 32 },
                { icon: "skip_previous", act: "prev", w: 44, h: 36 },
                { icon: root.playing ? "pause" : "play_arrow", act: "toggle", w: 62, h: 40 },
                { icon: "skip_next", act: "next", w: 44, h: 36 },
                { icon: "forward_10", act: "fwd", w: 38, h: 32 }
            ]

            delegate: Item {
                id: btn
                required property var modelData

                readonly property bool usable: {
                    if (!root.source || !root.player)
                        return false
                    switch (btn.modelData.act) {
                    case "prev": return root.player.canGoPrevious
                    case "next": return root.player.canGoNext
                    case "toggle": return root.player.canTogglePlaying
                    default: return lane.seekable
                    }
                }
                readonly property bool main: btn.modelData.act === "toggle"
                readonly property bool small: btn.modelData.act === "back" || btn.modelData.act === "fwd"

                width: btn.modelData.w
                height: root.keysH
                opacity: btn.usable ? 1 : 0.4

                Pill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: btn.modelData.w
                    height: btn.modelData.h
                    cornerRadius: btn.main ? 13 : 11
                    ringWidth: btn.small ? 4 : 5
                    fillColor: btn.main ? Theme.accentCyan : Theme.surface
                    pressed: btnArea.pressed

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: btn.modelData.icon
                        size: btn.main ? 24 : (btn.small ? 18 : 20)
                        fill: 1
                        color: btn.main ? Theme.colBorder : Theme.ink
                    }
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    enabled: btn.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const a = btn.modelData.act
                        if (a === "prev")
                            root.source.previous()
                        else if (a === "next")
                            root.source.next()
                        else if (a === "back")
                            root.seekBy(-10)
                        else if (a === "fwd")
                            root.seekBy(10)
                        else
                            root.source.togglePlaying()
                    }
                }
            }
        }
    }
}
