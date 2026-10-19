import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import "MediaOwner.js" as Owner
import "MediaMath.js" as MM
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.bar
import qs.modules.sekai.visualizer

// The card that drops down from the media pill: a header plate with the cover and
// the song, a seek lane, and the keys. It is the shared SekaiPopup frame (pop-in,
// focus grab, placement and Escape come from SekaiPopup.qml); Bar.qml gives it
// `source`, the MediaSource, so the pill's player is the one shown first.
//
//   +----------------------------------------+
//   | [ZEN] [mpv]                            |   tabs: only when there is more than one player
//   | .--------------------------------------.
//   | | +------+  * ZEN TWILIGHT   [PLAYING] |   the plate (SekaiPlate, the header the Weather /
//   | | |COVER |  Title (two lines)          |   Calendar / Battery cards share) in the cover's
//   | | +------+  Artist                     |   own two colours; the cover is tilted and is a key
//   | '--------------------------------------'
//   | [1:12] =====<>---------------- [3:05]  |   the seek lane: drag or click to change the time
//   | [EQ] [ prev ] [ > Play ] [ next ] [win] |
//   +----------------------------------------+
//
//   The plate    the cover's two colours (the theme's accents when there is no cover) with
//                the halftone and light bands of the other cards. The state chip says
//                PLAYING / PAUSED / IDLE.
//   The cover    a keycap: raised while the song plays, pressed flush when paused. Click it
//                to play / pause.
//   The lane     elapsed time, a track with a diamond playhead, and the length. Press on the
//                track and drag (or just click) to jump: the position is only sent when you
//                let go, so a drag never stutters the player. The wheel over it seeks by five
//                seconds. Click the length to flip it to the time left. A song with no known
//                length (a live stream) shows the lane dimmed and does nothing.
//   The play key wears the cover's own two colours (or the theme's accent when there
//                is no cover); everything else is the shell's plain card.
//   The tabs     one per app (Zen, Chromium and mpv can report several players; the bar
//                pill's player comes first). Click one, or roll the wheel over them.
//                With one player its name sits on the plate instead.
//   The keys     previous / play-pause / next; the tools at the ends open the equalizer
//                and the player's own window (workspace and all). A key the player cannot
//                do is dimmed.
//   Keyboard     Space plays / pauses, N / P next / previous, Left / Right seek by five
//                seconds (best effort, whenever the compositor gives the popup the
//                keyboard).
//
// Nothing runs on its own: the position is asked for once a second, and only while the card
// is open and the song is playing. Every colour is a Theme token (or the cover's / the
// app's), so Light, Dark and Darker all work.
SekaiPopup {
    id: root

    property var source: null          // MediaSource (which player the pill shows)

    // The EQ tool was pressed: Bar.qml puts this card away and opens the equalizer
    // card (EqualizerPopup.qml) in its place.
    signal eqRequested()

    // ===== the players =====
    readonly property var players: {
        const featured = root.source ? root.source.player : null
        const live = Mpris.players.values.filter(pl =>
            pl.playbackState === MprisPlaybackState.Playing || (pl.trackTitle ?? "") !== "")
        // One card per app: Zen, Chromium and mpv can report several players.
        const list = Owner.onePerApp(live, Hyprland.toplevels.values, featured, MprisPlaybackState.Playing)
        return list.slice().sort((a, b) => (b === featured ? 1 : 0) - (a === featured ? 1 : 0))
    }

    // The one you turned to (null = the first). Forgotten each time the card opens.
    property var picked: null
    readonly property var p: MM.current(root.players, root.picked)
    readonly property bool hasPlayer: root.p !== null
    readonly property bool multi: root.players.length > 1
    readonly property int playerNo: root.hasPlayer ? Math.max(0, root.players.indexOf(root.p)) + 1 : 0
    readonly property bool featured: root.hasPlayer && root.source !== null && root.p === root.source.player

    readonly property bool playing: root.hasPlayer && root.p.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.hasPlayer && (root.p.trackTitle ?? "") !== ""
    readonly property real length: root.hasPlayer && root.p.lengthSupported ? Math.max(0, root.p.length) : 0
    readonly property bool seekable: root.hasPlayer && root.p.canSeek && root.p.positionSupported && root.length > 0

    // ===== the seek lane =====
    readonly property bool hasLength: root.hasPlayer && root.p.positionSupported && root.length > 0
    readonly property real position: root.hasPlayer && root.p.positionSupported ? Math.max(0, root.p.position) : 0

    // While the pointer is down on the track the playhead follows it (`scrubFrac`) and the
    // player is left alone; the jump is sent on release. For half a second after that the
    // playhead stays where it was dropped (`settleFrac`), so it does not flick back to the
    // old time before the player has reported the new one.
    property bool scrubbing: false
    property real scrubFrac: 0
    property real settleFrac: -1
    // The right-hand chip: the length (false) or the time left (true).
    property bool showLeft: false

    readonly property real frac: root.scrubbing ? root.scrubFrac
        : (root.settleFrac >= 0 ? root.settleFrac : MM.ratio(root.position, root.length))
    readonly property real shownSec: root.hasLength ? root.frac * root.length : root.position
    readonly property string elapsedText: root.hasLength || (root.hasPlayer && root.p.positionSupported)
        ? MM.fmt(root.shownSec) : "--:--"
    readonly property string totalText: !root.hasLength ? "--:--"
        : (root.showLeft ? MM.left(root.shownSec, root.length) : MM.fmt(root.length))

    // Which window this player lives in (see MediaOwner.js). Reading
    // Hyprland.toplevels.values keeps it live as windows come and go.
    readonly property var ownerInfo: root.hasPlayer ? Owner.resolve(root.p, Hyprland.toplevels.values)
                                                    : { matches: [], viaFallback: false }
    readonly property bool usingLua: Hyprland.usingLua !== false

    // The name on a tab: the player's identity, or, when it is really a Firefox
    // fork wearing Firefox's name, the window's class ("zen-twilight" -> "Zen
    // Twilight"). Reading Hyprland.toplevels.values keeps it live.
    function labelFor(pl) {
        if (!pl)
            return "Media"
        let raw = String(pl.identity ?? "")
        const info = Owner.resolve(pl, Hyprland.toplevels.values)
        if (info.viaFallback && info.matches.length > 0)
            raw = Owner.classOf(info.matches[0]).split(".").pop()
        return MM.appLabel(raw)
    }

    // One of the five SEKAI attribute colours per app, the same one every time.
    function toneFor(name) {
        return Theme.attributeColors[MM.pickIndex(name, Theme.attributeColors.length)]
    }

    readonly property string appName: root.labelFor(root.hasPlayer ? root.p : null)
    readonly property color appColor: root.toneFor(root.appName)

    // Cover art: the player's own, else a YouTube tab's thumbnail.
    readonly property string art: {
        if (!root.hasPlayer)
            return ""
        const direct = root.p.trackArtUrl ?? ""
        if (direct !== "")
            return direct
        const md = root.p.metadata
        return MM.youtubeThumb(md ? md["xesam:url"] : undefined)
    }

    readonly property string trackKey: root.hasPlayer ? String(root.p.trackTitle ?? "") + "|" + String(root.p.trackArtist ?? "") : ""
    readonly property string subLine: {
        if (!root.hasPlayer)
            return ""
        const artist = String(root.p.trackArtist ?? "")
        const album = String(root.p.trackAlbum ?? "")
        return artist !== "" && album !== "" ? artist + "  ·  " + album : artist + album
    }

    // Take the person to the player's window, workspace included.
    //
    // MprisPlayer.raise() only asks the player to raise itself, which browsers
    // answer with a taskbar "attention" flash and no workspace switch under
    // Hyprland. So use the window found above: prefer the one whose title
    // carries the track title (a browser's title is its active tab), then the
    // focused one, then any. Switch to its workspace first and focus it second
    // (what the dock does, since focuswindow alone doesn't always cross
    // workspaces). No window found: fall back to the player's own raise().
    function openPlayerWindow() {
        if (!root.hasPlayer)
            return
        const matches = root.ownerInfo.matches
        if (matches.length === 0) {
            if (root.p.canRaise)
                root.p.raise()
            return
        }

        const title = String(root.p.trackTitle ?? "").toLowerCase()
        const target = (title !== "" ? matches.find(t => String(t.title ?? t.lastIpcObject?.title ?? "").toLowerCase().indexOf(title) !== -1) : null)
            ?? matches.find(t => t.activated)
            ?? matches[0]

        let address = String(target.address ?? target.lastIpcObject?.address ?? "")
        if (address === "")
            return
        if (address.indexOf("0x") !== 0)
            address = "0x" + address

        const ws = target.workspace?.id ?? target.lastIpcObject?.workspace?.id
        if (ws !== undefined && ws !== null)
            Hyprland.dispatch(root.usingLua
                ? "hl.dsp.focus({ workspace = " + ws + " })"
                : "workspace " + ws)
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.focus({ window = \"address:" + address + "\" })"
            : "focuswindow address:" + address)
    }

    // Jump to a point of the song (0..1). (The player does not announce its position, so
    // ask for it first.)
    function seekToFrac(f) {
        if (!root.seekable)
            return
        const t = Math.max(0, Math.min(1, f))
        root.p.positionChanged()
        root.p.position = Math.max(0, Math.min(root.length, t * root.length))
        root.settleFrac = t
        settleTimer.restart()
    }

    function seekBy(sec) {
        if (!root.seekable)
            return
        root.p.positionChanged()
        root.seekToFrac((root.p.position + sec) / root.length)
    }

    onKeyed: event => {
        if (!root.hasPlayer)
            return
        if (event.key === Qt.Key_Space && root.p.canTogglePlaying) {
            root.p.togglePlaying()
            event.accepted = true
        } else if (event.key === Qt.Key_N && root.p.canGoNext) {
            root.p.next()
            event.accepted = true
        } else if (event.key === Qt.Key_P && root.p.canGoPrevious) {
            root.p.previous()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.seekBy(5)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.seekBy(-5)
            event.accepted = true
        }
    }

    // ===== the design =====
    readonly property int pad: 16
    readonly property int innerW: 304
    readonly property int coverSize: 76

    contentWidth: root.innerW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    // ===== colours =====
    // The cover's colours, for the play key (the visualizer's reader: it downloads a
    // web cover once into the cache, ColorQuantizer takes the most saturated colours
    // and lifts them so the dark ink reads on them).
    VisualizerCover {
        id: cover
        artUrl: root.art
        enabled: root.hasTrack
    }
    readonly property var coverColors: cover.palette
    readonly property color tone: root.coverColors ? Qt.lighter(root.coverColors[0], 1.06) : Theme.accentMint
    readonly property color tone2: root.coverColors ? root.coverColors[1] : Theme.accentCyan

    // The plate wears the same two colours, easing from one song's to the next.
    property color plateTop: root.tone
    property color plateBottom: root.tone2
    Behavior on plateTop {
        ColorAnimation { duration: 300 }
    }
    Behavior on plateBottom {
        ColorAnimation { duration: 300 }
    }

    // The player does not announce its position: ask for it while the card is open and
    // the song is playing (and not while the pointer holds the playhead).
    Timer {
        interval: 1000
        repeat: true
        running: root.open && root.playing && !root.scrubbing
        onTriggered: root.p.positionChanged()
    }
    Timer {
        id: settleTimer
        interval: 500
        onTriggered: root.settleFrac = -1
    }

    // A fresh reading whenever the card opens, the song changes or another player is
    // picked (a paused player would otherwise show an old time).
    function refreshPosition() {
        if (root.hasPlayer)
            root.p.positionChanged()
    }
    onTrackKeyChanged: {
        root.settleFrac = -1
        root.refreshPosition()
    }
    onPChanged: {
        root.settleFrac = -1
        root.refreshPosition()
    }

    onOpenChanged: {
        if (open) {
            root.picked = null
            root.settleFrac = -1
            root.scrubbing = false
            root.refreshPosition()
        }
    }

    // The words: the title, then the artist under it (a video with no artist: the
    // album, or the app).
    readonly property string artistText: root.hasPlayer ? String(root.p.trackArtist ?? "") : ""
    readonly property string titleText: root.hasPlayer ? String(root.p.trackTitle ?? "") : ""
    readonly property string line1: {
        if (!root.hasPlayer)
            return "Nothing playing"
        if (root.titleText !== "")
            return root.titleText
        return root.artistText !== "" ? root.artistText : root.appName
    }
    readonly property string line2: {
        if (!root.hasPlayer)
            return "Start a song or a video"
        if (root.titleText === "")
            return ""
        if (root.artistText !== "")
            return root.artistText
        const album = String(root.p.trackAlbum ?? "")
        return album !== "" ? album : root.appName
    }

    // ===== the card =====
    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.innerW
        spacing: 12

        // ===== the tabs (only with more than one player) =====
        Item {
            id: tabBox
            visible: root.multi
            width: stack.width
            height: 24

            Row {
                id: tabRow
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 4
                clip: true

                Repeater {
                    // An integer model: the delegates stay put while the list updates.
                    model: root.hasPlayer ? root.players.length : 0

                    delegate: MediaTab {
                        id: tab
                        required property int index
                        readonly property var pl: root.players[tab.index] ?? null

                        active: tab.pl === root.p
                        text: root.labelFor(tab.pl)
                        tone: root.toneFor(root.labelFor(tab.pl))
                        onClicked: {
                            if (!tab.active && tab.pl)
                                root.picked = tab.pl
                        }
                    }
                }
            }

            Timer {
                id: wheelGate
                interval: 160
            }
            MouseArea {
                anchors.fill: tabRow
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheelGate.running) {
                        wheel.accepted = true
                        return
                    }
                    wheelGate.restart()
                    root.picked = wheel.angleDelta.y < 0 ? MM.nextPlayer(root.players, root.p)
                                                         : MM.prevPlayer(root.players, root.p)
                    wheel.accepted = true
                }
            }
        }

        // ===== the plate: the cover, the song and the state =====
        SekaiPlate {
            id: song
            width: stack.width
            height: 112
            colorTop: root.plateTop
            colorBottom: root.plateBottom
            dotCorner: "tr"

            // The cover: a keycap, tilted a little. Raised while the song plays, pressed
            // flush when it is paused. Click it to play / pause.
            Pill {
                id: jacket
                x: 14
                y: 14
                width: root.coverSize
                height: root.coverSize + Theme.shadowOffset
                cornerRadius: 18
                ringWidth: 5
                fillColor: Theme.surfaceHover
                pressed: jacketArea.pressed || !root.playing
                rotation: -4
                transformOrigin: Item.Center

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Math.max(0, jacket.cornerRadius - jacket.ringWidth)
                    color: Theme.surfaceHover

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: coverImage.status !== Image.Ready
                        name: root.hasTrack ? "music_note" : "music_off"
                        size: 36
                        fill: 0
                        color: Theme.inkSub
                    }

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: root.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        cache: false
                        sourceSize: Qt.size(240, 240)
                        opacity: root.playing ? 1 : 0.9
                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }

                    // Hover: what pressing it does.
                    Rectangle {
                        anchors.fill: parent
                        color: "#55000000"
                        opacity: jacketArea.containsMouse && jacketArea.enabled ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: root.playing ? "pause" : "play_arrow"
                            size: 38
                            fill: 0
                            weight: 500
                            color: Theme.textWhite
                        }
                    }
                }
            }

            MouseArea {
                id: jacketArea
                x: jacket.x
                y: jacket.y
                width: jacket.width
                height: jacket.height
                enabled: root.hasPlayer && root.p.canTogglePlaying
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.p.togglePlaying()
            }

            // The app, as a small gem and its name (with several players the tabs
            // above say it instead).
            Row {
                id: appRow
                visible: !root.multi
                x: root.coverSize + 30
                y: 13
                spacing: 6

                DiamondDot {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 7
                    lit: true
                    litColor: Theme.textWhite
                    lineColor: Theme.colBorder
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 100)
                    elide: Text.ElideRight
                    text: root.appName.toUpperCase()
                    color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.82)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 1.4
                }
            }

            // The state, as a small tilted chip (like the AM / PM and percent chips of the
            // desktop widgets).
            Pill {
                id: stateChip
                x: song.width - width - 12
                y: 6
                width: stateRow.implicitWidth + 28
                height: 32
                cornerRadius: 11
                ringWidth: 5
                fillColor: Theme.chipFill
                rotation: 3
                transformOrigin: Item.Center

                Row {
                    id: stateRow
                    anchors.centerIn: parent
                    spacing: 5

                    DiamondDot {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 6
                        lit: root.playing
                        litColor: root.tone
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.playing ? "PLAYING" : (root.hasTrack ? "PAUSED" : "IDLE")
                        color: Theme.chipInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 1
                    }
                }
            }

            // The words, in the plate's dark ink.
            Column {
                id: info
                x: root.coverSize + 30
                y: 40 + Math.max(0, (62 - info.implicitHeight) / 2)
                width: song.width - x - 14
                spacing: 3

                Text {
                    width: parent.width
                    text: root.line1
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.95
                    color: Theme.colBorder
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    width: parent.width
                    visible: root.line2 !== ""
                    text: root.line2
                    elide: Text.ElideRight
                    color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.8)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        // ===== the seek lane: [elapsed] ===<>------- [length] =====
        Item {
            id: lane
            width: stack.width
            height: 34
            opacity: root.hasLength ? 1 : 0.45
            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            Pill {
                id: elapsedChip
                width: 64
                height: 34
                cornerRadius: 12
                ringWidth: 5
                fillColor: Theme.chipFill
                rotation: -3
                transformOrigin: Item.Center
                // Sinks like a key while you hold the playhead.
                pressed: root.scrubbing

                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.elapsedText
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }

            Item {
                id: track
                x: elapsedChip.width + 10
                width: lane.width - 2 * (elapsedChip.width + 10)
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2

                readonly property real headSize: 13
                readonly property real headX: Math.min(track.width - track.headSize,
                                                       Math.max(0, track.width * root.frac - track.headSize / 2))

                Rectangle {
                    id: groove
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 12
                    radius: 6
                    color: Theme.surfaceDivider
                    border.width: 2
                    border.color: Theme.line
                    antialiasing: true
                }

                // What has played.
                Rectangle {
                    id: trail
                    x: 2
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8
                    radius: 4
                    width: Math.max(0, track.headX + track.headSize / 2 - 2)
                    antialiasing: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.tone }
                        GradientStop { position: 1.0; color: root.tone2 }
                    }
                    Behavior on width {
                        enabled: !root.scrubbing
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }

                // The playhead: a diamond note, a little bigger while you hold it.
                Rectangle {
                    id: head
                    anchors.verticalCenter: parent.verticalCenter
                    x: track.headX
                    width: track.headSize
                    height: track.headSize
                    radius: 3
                    rotation: 45
                    color: root.tone
                    border.width: 2
                    border.color: Theme.line
                    antialiasing: true
                    scale: root.scrubbing ? 1.35 : (seekArea.containsMouse ? 1.15 : 1)
                    Behavior on x {
                        enabled: !root.scrubbing
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                    }
                }

                // Press and drag, or click, to jump; the wheel seeks by five seconds.
                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    enabled: root.seekable
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    function fracAt(mx) {
                        return Math.max(0, Math.min(1, mx / Math.max(1, width)))
                    }

                    onPressed: mouse => {
                        root.scrubFrac = seekArea.fracAt(mouse.x)
                        root.scrubbing = true
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            root.scrubFrac = seekArea.fracAt(mouse.x)
                    }
                    onReleased: mouse => {
                        if (root.scrubbing)
                            root.seekToFrac(seekArea.fracAt(mouse.x))
                        root.scrubbing = false
                    }
                    onCanceled: root.scrubbing = false
                    onWheel: wheel => {
                        root.seekBy(wheel.angleDelta.y > 0 ? 5 : -5)
                        wheel.accepted = true
                    }
                }
            }

            // The length; click it to see the time left instead.
            Pill {
                id: totalChip
                x: lane.width - width
                width: 64
                height: 34
                cornerRadius: 12
                ringWidth: 5
                fillColor: totalArea.containsMouse && root.hasLength ? Theme.surfaceHover : Theme.chipFill
                rotation: 3
                transformOrigin: Item.Center
                pressed: totalArea.pressed && root.hasLength

                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.totalText
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
            MouseArea {
                id: totalArea
                x: totalChip.x
                width: totalChip.width
                height: totalChip.height
                enabled: root.hasLength
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.showLeft = !root.showLeft
            }
        }

        // ===== the keys: [EQ] [prev] [play] [next] [window] =====
        Row {
            id: keys
            height: 48          // the tall keys' height; the small tool keys centre in it
            spacing: 6

            MediaKey {
                y: Math.round((keys.height - height) / 2)
                compact: true
                icon: "equalizer"
                onClicked: root.eqRequested()
            }
            MediaKey {
                width: 56
                icon: "skip_previous"
                available: root.hasPlayer && root.p.canGoPrevious
                onClicked: root.p.previous()
            }
            MediaKey {
                width: 92
                primary: true
                icon: root.playing ? "pause" : "play_arrow"
                label: root.playing ? "Pause" : "Play"
                toneTop: root.tone
                toneBottom: root.tone2
                available: root.hasPlayer && root.p.canTogglePlaying
                onClicked: root.p.togglePlaying()
            }
            MediaKey {
                width: 56
                icon: "skip_next"
                available: root.hasPlayer && root.p.canGoNext
                onClicked: root.p.next()
            }
            MediaKey {
                y: Math.round((keys.height - height) / 2)
                compact: true
                icon: "open_in_new"
                available: root.hasPlayer
                onClicked: root.openPlayerWindow()
            }
        }
    }
}
