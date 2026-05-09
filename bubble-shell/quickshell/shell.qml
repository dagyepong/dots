import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Widgets

ShellRoot {
    id: dock

    readonly property int edgePad: 8
    readonly property int pillGap: 8
    // clockPillW/settingsPillW chase each other's actual implicitWidths so
    // neighboring panels can anchor against them without a binding loop.
    property int clockPillW: 77
    property int settingsPillW: 88

    NotificationModule { id: notifMod }

    // One-shot cleanup of stale /tmp album-art caches from prior sessions.
    // `-mtime +1` spares anything touched in the last 24h so we never delete
    // the currently-playing track's art mid-session.
    Process {
        id: artCleanupProc
        running: true
        property string _stderr: ""
        command: ["find", "/tmp", "-maxdepth", "1", "-name",
            "quickshell-album-*.img", "-mtime", "+1", "-delete"]
        stderr: StdioCollector { onStreamFinished: artCleanupProc._stderr = text }
        onExited: (code) => {
            if (code !== 0) console.warn("[shell] art cleanup failed (exit",
                code + "):", artCleanupProc._stderr.trim() || "(no stderr)")
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clockPanel

            required property var modelData
            screen: modelData

            anchors { bottom: true; right: true }
            margins { bottom: dock.edgePad; right: dock.edgePad }

            implicitWidth: 260
            implicitHeight: 48
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-clock"
            exclusionMode: ExclusionMode.Ignore

            Pill {
                id: clockPill
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                collapsedWidth: timeHM.implicitWidth + 3 + timeAMPM.implicitWidth + 20
                expandedWidth:  dateLabel.implicitWidth + 6 + timeHM.implicitWidth + 3 + timeAMPM.implicitWidth + 20
                pillHeight: 36

                onImplicitWidthChanged: dock.clockPillW = implicitWidth
                Component.onCompleted: dock.clockPillW = implicitWidth

                Text {
                    id: timeAMPM
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.family: "Geist"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: -0.12
                }

                Text {
                    id: timeHM
                    anchors.right: timeAMPM.left
                    anchors.rightMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: "Geist"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: -0.12
                }

                Text {
                    id: dateLabel
                    anchors.right: timeHM.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: "Geist"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: -0.12
                    opacity: clockPill.hovered ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        const d = new Date()
                        const h = d.getHours()
                        const h12 = h % 12 || 12
                        const mm = d.getMinutes().toString().padStart(2, '0')
                        timeHM.text = h12 + ":" + mm
                        timeAMPM.text = h >= 12 ? "PM" : "AM"
                        dateLabel.text = Qt.formatDate(d, "ddd, MMM d")
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: settingsPanel

            required property var modelData
            screen: modelData

            anchors { bottom: true; right: true }
            margins {
                bottom: dock.edgePad
                right: dock.edgePad + dock.clockPillW + dock.pillGap
            }

            implicitWidth: 250
            implicitHeight: 280
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-clock"
            WlrLayershell.keyboardFocus: settingsExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            // Without this mask, the transparent upper region of the panel
            // surface would still swallow pointer events from adjacent windows.
            mask: Region { item: settingsPill }

            readonly property var batteryDevice: UPower.displayDevice
            readonly property bool _batteryReady: batteryDevice && batteryDevice.ready && batteryDevice.isPresent
            readonly property int _batteryPercent: {
                if (!_batteryReady) return 0
                if (batteryDevice.state === UPowerDeviceState.FullyCharged) return 100
                return Math.round(batteryDevice.percentage * 100)
            }
            readonly property bool _batteryCharging: _batteryReady &&
                (batteryDevice.state === UPowerDeviceState.Charging
                 || batteryDevice.state === UPowerDeviceState.FullyCharged)

            NetworkService { id: net }
            PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

            property bool settingsExpanded: false

            HyprlandFocusGrab {
                active: settingsPanel.settingsExpanded
                windows: [settingsPanel]
                onCleared: settingsPanel.settingsExpanded = false
            }

            onSettingsExpandedChanged: {
                if (!settingsExpanded) {
                    settingsContent.view = SettingsContent.View.Settings
                    settingsContent.passwordRowSsid = ""
                    settingsContent.showPassword = false
                    settingsContent.connectError = ""
                    volumeOsdShowing = false
                }
            }

            property bool volumeOsdShowing: false
            property bool _volumeInit: false
            readonly property int osdFullWidth: 160
            readonly property var _sinkAudio: Pipewire.defaultAudioSink?.audio ?? null
            readonly property real _currentVol: _sinkAudio?.volume ?? 0

            Timer {
                id: volumeInitTimer
                interval: 1000; running: true
                onTriggered: settingsPanel._volumeInit = true
            }

            Timer {
                id: osdHideTimer
                interval: 2000
                onTriggered: settingsPanel.volumeOsdShowing = false
            }

            Connections {
                target: settingsPanel._sinkAudio
                function onVolumeChanged() {
                    if (settingsPanel._volumeInit && !settingsPanel.settingsExpanded) {
                        settingsPanel.volumeOsdShowing = true
                        osdHideTimer.restart()
                    }
                }
                function onMutedChanged() {
                    if (settingsPanel._volumeInit && !settingsPanel.settingsExpanded) {
                        settingsPanel.volumeOsdShowing = true
                        osdHideTimer.restart()
                    }
                }
            }

            readonly property int wifiLevel: net.signalLevel(net.connectedSignal)

            Pill {
                id: settingsPill
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                onImplicitWidthChanged: dock.settingsPillW = implicitWidth
                Component.onCompleted: dock.settingsPillW = implicitWidth

                // Battery icon is omitted entirely when there is no display device.
                readonly property int iconsBaseWidth: 20
                    + (batteryIconItem.visible ? batteryIconItem.width + 4 : 0)
                    + wifiIconItem.width + 4 + gridIconItem.width
                readonly property int volExtraWidth: 120
                readonly property int percentExtraWidth: batteryIconItem.visible
                    ? batteryPercentText.implicitWidth + 4
                    : 0
                collapsedWidth: iconsBaseWidth
                    + (!settingsPanel.settingsExpanded && settingsPanel.volumeOsdShowing ? volExtraWidth : 0)
                expandedWidth:  collapsedWidth + percentExtraWidth
                pillHeight: 36

                activeWidth: settingsPanel.settingsExpanded ? settingsContent.viewWidth : -1
                activeHeight: settingsPanel.settingsExpanded ? settingsContent.viewHeight : -1
                activeCornerRadius: settingsPanel.settingsExpanded ? 16 : -1

                GridIcon {
                    id: gridIconItem
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (settingsPill.pillHeight - height) / 2
                    opacity: settingsPanel.settingsExpanded ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                WifiIcon {
                    id: wifiIconItem
                    anchors.right: gridIconItem.left
                    anchors.rightMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (settingsPill.pillHeight - height) / 2
                    signalLevel: settingsPanel.wifiLevel
                    opacity: settingsPanel.settingsExpanded ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Width Behavior must share duration with the pill's implicitWidth
                // Behavior so the text reveal stays in lockstep with the expansion.
                Item {
                    id: percentSlot
                    anchors.right: wifiIconItem.left
                    anchors.rightMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (settingsPill.pillHeight - height) / 2
                    height: 20
                    width: settingsPill.hovered && batteryIconItem.visible
                        ? batteryPercentText.implicitWidth
                        : 0
                    clip: true
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    Text {
                        id: batteryPercentText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: settingsPanel._batteryPercent + "%"
                        color: Qt.rgba(1, 1, 1, 0.8)
                        font.family: "Geist"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        font.letterSpacing: -0.14
                    }
                }

                BatteryIcon {
                    id: batteryIconItem
                    visible: settingsPanel._batteryReady
                    anchors.right: percentSlot.left
                    // No explicit gap to a 0-width slot — collapses to the
                    // 4px gap reserved by percentSlot's own anchors.rightMargin.
                    anchors.rightMargin: percentSlot.width > 0 ? 4 : 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (settingsPill.pillHeight - height) / 2
                    percent: settingsPanel._batteryPercent
                    isCharging: settingsPanel._batteryCharging
                    opacity: settingsPanel.settingsExpanded ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Shape {
                    id: osdSpeaker
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (settingsPill.pillHeight - height) / 2
                    width: 9; height: 14
                    visible: settingsPanel.volumeOsdShowing
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 4.5; y1: -18; x2: 4.5; y2: 30
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        PathSvg { path: "M1.5 10H3L7.19063 13.725C7.39063 13.9031 7.64688 14 7.9125 14C8.5125 14 9 13.5125 9 12.9125V1.0875C9 0.4875 8.5125 0 7.9125 0C7.64688 0 7.39063 0.0968751 7.19063 0.275L3 4H1.5C0.671875 4 0 4.67187 0 5.5V8.5C0 9.32812 0.671875 10 1.5 10Z" }
                    }
                }

                Item {
                    id: osdSlider
                    anchors.left: osdSpeaker.right
                    anchors.leftMargin: 6
                    // Anchor to whichever icon is leftmost in the cluster —
                    // battery (when present) sits to the left of wifi, so the
                    // slider would otherwise overlap the battery icon.
                    anchors.right: batteryIconItem.visible ? batteryIconItem.left : wifiIconItem.left
                    anchors.rightMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (settingsPill.pillHeight - height) / 2
                    height: 14
                    visible: settingsPanel.volumeOsdShowing

                    Rectangle {
                        id: osdTrackBg
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 6; radius: 3
                        color: Qt.rgba(0.859, 0.839, 0.792, 0.3)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: osdTrackBg.width * Math.min(1.0, settingsPanel._currentVol)
                        height: 6; radius: 3
                        color: Qt.rgba(0.859, 0.839, 0.792, 1.0)
                    }

                    MouseArea {
                        anchors.fill: parent; anchors.margins: -4
                        onPressed: (mouse) => { setVol(mouse); osdHideTimer.restart() }
                        onPositionChanged: (mouse) => { if (pressed) { setVol(mouse); osdHideTimer.restart() } }
                        function setVol(mouse) {
                            const v = Math.max(0, Math.min(1, (mouse.x + 4) / osdSlider.width))
                            if (settingsPanel._sinkAudio) {
                                settingsPanel._sinkAudio.muted = false
                                settingsPanel._sinkAudio.volume = v
                            }
                        }
                    }
                }

                SettingsContent {
                    id: settingsContent
                    anchors.fill: parent
                    visible: settingsPanel.settingsExpanded
                    net: net
                    sink: Pipewire.defaultAudioSink
                    battery: settingsPanel.batteryDevice
                }

                onClicked: {
                    settingsPanel.volumeOsdShowing = false
                    settingsPanel.settingsExpanded = !settingsPanel.settingsExpanded
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: musicPanel

            required property var modelData
            screen: modelData

            anchors { bottom: true; right: true }
            margins {
                bottom: dock.edgePad
                right: dock.edgePad + dock.clockPillW + dock.pillGap + dock.settingsPillW + dock.pillGap
            }

            implicitWidth: 286
            implicitHeight: 286
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-clock"
            WlrLayershell.keyboardFocus: musicExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            mask: Region { item: musicPill }

            property var player: null
            readonly property bool hasPlayer: player !== null
            visible: hasPlayer

            function updatePlayer() {
                if (!Mpris.players || !Mpris.players.values) { player = null; return }
                let all = Mpris.players.values
                let playing = null
                let fallback = null
                for (let i = 0; i < all.length; i++) {
                    if (!all[i]) continue
                    if (all[i].playbackState === MprisPlaybackState.Playing) { playing = all[i]; break }
                    if (!fallback && all[i].canPlay) fallback = all[i]
                }
                player = playing || fallback || null
            }

            Component.onCompleted: updatePlayer()

            Connections {
                target: Mpris.players
                function onValuesChanged() { musicPanel.updatePlayer() }
            }

            property bool musicExpanded: false

            readonly property bool isNormal: !musicPill.hovered && !musicExpanded
            readonly property bool isHover: musicPill.hovered && !musicExpanded
            readonly property bool isExpanded: musicExpanded

            readonly property bool isPlaying: player ? (player.playbackState === MprisPlaybackState.Playing) : false
            readonly property string trackTitle: player ? (player.trackTitle || "") : ""
            readonly property string trackAlbum: player ? (player.trackAlbum || "") : ""
            readonly property string trackArtUrl: player ? (player.trackArtUrl || "") : ""

            HyprlandFocusGrab {
                active: musicPanel.musicExpanded
                windows: [musicPanel]
                onCleared: musicPanel.musicExpanded = false
            }

            Pill {
                id: musicPill
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                collapsedWidth: 78
                expandedWidth: 200
                pillHeight: 36

                activeWidth: musicPanel.musicExpanded ? 274 : -1
                activeHeight: musicPanel.musicExpanded ? 274 : -1
                activeCornerRadius: musicPanel.musicExpanded ? 16 : -1

                property color dominantColor: Qt.rgba(0.349, 0.557, 1.0, 1.0)
                themeColor: dominantColor

                // Only in expanded state: flip text to black when the album is
                // bright enough that white would wash out. ^0.678 approximates
                // CIE L* so the 0.5 threshold sits at perceptual midpoint.
                readonly property bool _fgDark: {
                    if (!musicPanel.musicExpanded) return false
                    const c = dominantColor
                    const Y = 0.2126 * Math.pow(c.r, 2.2)
                          + 0.7152 * Math.pow(c.g, 2.2)
                          + 0.0722 * Math.pow(c.b, 2.2)
                    const Ls = Math.pow(Y, 0.678)
                    return Ls > 0.5
                }
                readonly property color _fg:        _fgDark ? "black" : "white"
                readonly property color _fgInverse: _fgDark ? "white" : "black"

                // ColorQuantizer only handles local files — http(s) URLs (e.g. Spotify) fail
                // silently. Download remote URLs to /tmp and feed the local path instead.
                property string localArtPath: ""

                function refreshLocalArt(url) {
                    if (!url) { localArtPath = ""; return }
                    if (url.startsWith("file://") || url.startsWith("/")) {
                        localArtPath = url
                        return
                    }
                    const hash = Qt.md5(url).substring(0, 12)
                    const tmp = "/tmp/quickshell-album-" + hash + ".img"
                    artDownloader.outPath = tmp
                    artDownloader.srcUrl = url
                    artDownloader.running = true
                }

                Process {
                    id: artDownloader
                    property string outPath: ""
                    property string srcUrl: ""
                    command: ["curl", "-sfL", "--max-time", "10", "-o", outPath, srcUrl]
                    onExited: (exitCode) => {
                        if (exitCode === 0 && outPath !== "") {
                            musicPill.localArtPath = "file://" + outPath
                        } else {
                            console.warn("[music] art download failed (exit",
                                exitCode + ") for", srcUrl)
                        }
                    }
                }

                Connections {
                    target: musicPanel
                    function onTrackArtUrlChanged() { musicPill.refreshLocalArt(musicPanel.trackArtUrl) }
                }

                Component.onCompleted: refreshLocalArt(musicPanel.trackArtUrl)

                ColorQuantizer {
                    id: albumColors
                    source: musicPill.localArtPath
                    depth: 1
                    rescaleSize: 64
                    onColorsChanged: {
                        if (colors && colors.length > 0) {
                            musicPill.dominantColor = colors[0]
                        }
                    }
                }

                // Anchoring to the pill keeps the clipper and the pill sharing one
                // animated size, so there's no lag or leftover image on collapse.
                ClippingRectangle {
                    id: albumBg
                    anchors.fill: parent
                    z: 1
                    radius: musicPill._cornerRadius
                    color: "transparent"

                    // Source image for albumBlur — hidden via ShaderEffectSource;
                    // the blurred output renders in its place.
                    Image {
                        id: albumImage
                        width: 274; height: 274
                        x: 0
                        y: albumBg.height - 274
                        source: musicPanel.trackArtUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(274, 274)
                        visible: !musicPanel.isNormal
                    }

                    ShaderEffectSource {
                        id: albumImageSource
                        sourceItem: albumImage
                        hideSource: true
                        live: true
                    }

                    ShaderEffect {
                        id: albumBlur
                        width: 274; height: 274
                        x: 0
                        y: albumBg.height - 274
                        visible: albumImage.visible

                        property variant source: albumImageSource
                        property size iSize:      Qt.size(width, height)
                        property real maxBlur:    10.0
                        property real blurStart:  0.5

                        fragmentShader: Qt.resolvedUrl("album_blur.frag.qsb")
                    }

                    // Hover tint uses the inverse of the fg color, so bright albums
                    // get a white tint and dark albums get the usual darkening.
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(musicPill._fgInverse.r, musicPill._fgInverse.g, musicPill._fgInverse.b, 0.4)
                        visible: musicPanel.isHover
                    }

                    ShaderEffect {
                        anchors.fill: parent
                        visible: albumImage.visible
                        opacity: musicPanel.musicExpanded ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        property size  iSize:         Qt.size(width, height)
                        property real  cornerRadius:  albumBg.radius
                        property color glowColor:     Qt.rgba(musicPill.dominantColor.r,
                                                              musicPill.dominantColor.g,
                                                              musicPill.dominantColor.b, 0.95)
                        property real  glowRadius:    80.0
                        property real  glowIntensity: 1.0
                        property real  topWeight:     0.25

                        fragmentShader: Qt.resolvedUrl("album_glow.frag.qsb")
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: musicPanel.musicExpanded
                        onClicked: musicPanel.musicExpanded = false
                    }
                }


                Item {
                    id: titleContainer; z: 2
                    x: musicPanel.isExpanded ? 16 : 14
                    y: musicPanel.isExpanded ? 214 : 8
                    width: musicPanel.isExpanded ? 152 : (musicPanel.isHover ? 106 : 0)
                    height: 20
                    visible: !musicPanel.isNormal
                    clip: true
                    Behavior on x     { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on y     { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    Row {
                        id: titleScroller
                        spacing: 40
                        y: 0

                        property bool shouldScroll: musicPanel.isExpanded && titleText.implicitWidth > titleContainer.width && titleContainer.width > 0

                        NumberAnimation on x {
                            id: scrollAnim
                            running: titleScroller.shouldScroll
                            from: 0
                            to: -(titleText.implicitWidth + titleScroller.spacing)
                            duration: Math.max(4000, musicPanel.trackTitle.length * 120)
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                        }

                        onShouldScrollChanged: {
                            if (!shouldScroll) x = 0
                        }

                        Text {
                            id: titleText
                            text: musicPanel.trackTitle
                            color: musicPill._fg; opacity: 0.8
                            font.family: "Geist"
                            font.pixelSize: musicPanel.isExpanded ? 16 : 14
                            font.weight: Font.Medium
                            font.letterSpacing: musicPanel.isExpanded ? -0.16 : -0.14
                        }

                        // Duplicate for seamless loop
                        Text {
                            visible: titleScroller.shouldScroll
                            text: musicPanel.trackTitle
                            color: musicPill._fg; opacity: 0.8
                            font.family: "Geist"
                            font.pixelSize: musicPanel.isExpanded ? 16 : 14
                            font.weight: Font.Medium
                            font.letterSpacing: musicPanel.isExpanded ? -0.16 : -0.14
                        }
                    }
                }

                Text {
                    id: albumText; z: 2
                    x: 16
                    y: musicPanel.isExpanded ? 236 : 46
                    visible: musicPanel.isExpanded
                    text: musicPanel.trackAlbum
                    color: musicPill._fg; opacity: 0.5
                    font.family: "Geist"; font.pixelSize: 14
                    font.weight: Font.Normal; font.letterSpacing: -0.14
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }

                // Anchored right so the controls' screen position is fixed
                // while the pill grows leftward on hover/expand.
                Item {
                    id: controls; z: 3
                    anchors.right: parent.right
                    anchors.rightMargin: musicPanel.isExpanded
                        ? 16
                        : (musicPanel.isHover ? 10 : 8)
                    y: musicPanel.isExpanded ? 214 : 6
                    width: musicPanel.isExpanded ? 82 : 62
                    height: musicPanel.isExpanded ? 36 : 24
                    Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on y      { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on width  { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    Shape {
                        x: 0; y: musicPanel.isExpanded ? 13 : 7
                        width: 11; height: 10; opacity: 0.6
                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: musicPill._fg; strokeWidth: 1.5; fillColor: musicPill._fg
                            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                            PathSvg { path: "M9.686 3.377C9.727 3.349 9.775 3.333 9.826 3.329C9.877 3.325 9.928 3.334 9.973 3.355C10.018 3.376 10.057 3.408 10.083 3.447C10.11 3.487 10.124 3.532 10.124 3.578V8.422C10.124 8.469 10.11 8.514 10.083 8.553C10.057 8.593 10.018 8.625 9.973 8.645C9.928 8.666 9.877 8.675 9.826 8.671C9.775 8.668 9.727 8.651 9.686 8.624L6.07 6.201C6.035 6.178 6.007 6.148 5.988 6.113C5.968 6.078 5.958 6.039 5.958 6C5.958 5.961 5.968 5.922 5.988 5.887C6.007 5.853 6.035 5.822 6.07 5.799L9.686 3.377ZM4.644 3.377C4.685 3.349 4.734 3.333 4.784 3.329C4.835 3.325 4.886 3.334 4.931 3.355C4.977 3.376 5.015 3.408 5.042 3.447C5.068 3.487 5.082 3.532 5.082 3.578V8.422C5.082 8.469 5.068 8.514 5.042 8.553C5.015 8.593 4.977 8.625 4.931 8.645C4.886 8.666 4.835 8.675 4.784 8.671C4.734 8.668 4.685 8.651 4.644 8.624L1.028 6.201C0.994 6.178 0.966 6.148 0.946 6.113C0.927 6.078 0.917 6.039 0.917 6C0.917 5.961 0.927 5.922 0.946 5.887C0.966 5.853 0.994 5.822 1.028 5.799L4.644 3.377Z" }
                        }
                        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { if (musicPanel.player && musicPanel.player.canGoPrevious) musicPanel.player.previous() } }
                    }

                    Rectangle {
                        x: musicPanel.isExpanded ? 23 : 19
                        y: 0; width: parent.height; height: parent.height; radius: width / 2
                        color: Qt.rgba(musicPill._fg.r, musicPill._fg.g, musicPill._fg.b, 0.1)
                        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        Shape {
                            anchors.centerIn: parent
                            width: 8.33; height: 8.28; scale: parent.width / 24
                            preferredRendererType: Shape.CurveRenderer; visible: !musicPanel.isPlaying
                            ShapePath {
                                strokeColor: "transparent"; fillColor: musicPill._fg
                                PathSvg { path: "M7.747 2.824C7.958 2.937 8.134 3.107 8.257 3.314C8.38 3.521 8.445 3.758 8.445 4C8.445 4.242 8.38 4.479 8.257 4.686C8.134 4.894 7.958 5.063 7.747 5.177L2.128 8.273C1.223 8.772 0.111 8.123 0.111 7.097V0.904C0.111 -0.123 1.223 -0.771 2.128 -0.273L7.747 2.824Z" }
                            }
                        }
                        Row {
                            anchors.centerIn: parent; spacing: parent.width * 0.1; visible: musicPanel.isPlaying
                            Rectangle { width: parent.parent.width * 0.1; height: parent.parent.height * 0.38; radius: width / 2; color: musicPill._fg }
                            Rectangle { width: parent.parent.width * 0.1; height: parent.parent.height * 0.38; radius: width / 2; color: musicPill._fg }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { if (!musicPanel.player) return; if (musicPanel.player.playbackState === MprisPlaybackState.Playing) musicPanel.player.pause(); else musicPanel.player.play() } }
                    }

                    Shape {
                        x: musicPanel.isExpanded ? 71 : 51; y: musicPanel.isExpanded ? 13 : 7
                        width: 11; height: 10; opacity: 0.6
                        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: musicPill._fg; strokeWidth: 1.5; fillColor: musicPill._fg
                            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                            PathSvg { path: "M0.438 3.377C0.397 3.349 0.349 3.333 0.298 3.329C0.247 3.325 0.196 3.334 0.151 3.355C0.106 3.376 0.067 3.408 0.041 3.447C0.014 3.487 0 3.532 0 3.578V8.422C0 8.469 0.014 8.514 0.041 8.553C0.067 8.593 0.106 8.625 0.151 8.645C0.196 8.666 0.247 8.675 0.298 8.671C0.349 8.668 0.397 8.651 0.438 8.624L4.054 6.201C4.089 6.178 4.117 6.148 4.136 6.113C4.156 6.078 4.166 6.039 4.166 6C4.166 5.961 4.156 5.922 4.136 5.887C4.117 5.853 4.089 5.822 4.054 5.799L0.438 3.377ZM5.48 3.377C5.439 3.349 5.39 3.333 5.34 3.329C5.289 3.325 5.238 3.334 5.193 3.355C5.147 3.376 5.109 3.408 5.082 3.447C5.056 3.487 5.042 3.532 5.042 3.578V8.422C5.042 8.469 5.056 8.514 5.082 8.553C5.109 8.593 5.147 8.625 5.193 8.645C5.238 8.666 5.289 8.675 5.34 8.671C5.39 8.668 5.439 8.651 5.48 8.624L9.096 6.201C9.13 6.178 9.158 6.148 9.178 6.113C9.197 6.078 9.207 6.039 9.207 6C9.207 5.961 9.197 5.922 9.178 5.887C9.158 5.853 9.13 5.822 9.096 5.799L5.48 3.377Z" }
                        }
                        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { if (musicPanel.player && musicPanel.player.canGoNext) musicPanel.player.next() } }
                    }
                }

                onClicked: {
                    musicPanel.musicExpanded = !musicPanel.musicExpanded
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: workspacePanel

            required property var modelData
            screen: modelData

            anchors { bottom: true; left: true }
            margins {
                bottom: dock.edgePad
                // currentPillRightEdge already includes notifMod's leftEdgePad,
                // so only the inter-pill gap needs to be added.
                left: notifMod.currentPillRightEdge + dock.pillGap
            }

            implicitWidth: 120
            implicitHeight: 48
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-clock"
            exclusionMode: ExclusionMode.Ignore

            readonly property int currentWsId: Hyprland.focusedWorkspace?.id ?? 1

            Pill {
                id: workspacePill
                anchors.left: parent.left
                anchors.bottom: parent.bottom

                collapsedWidth: 94
                expandedWidth: 94
                pillHeight: 36

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Repeater {
                        model: 4

                        Item {
                            width: 6; height: 6
                            anchors.verticalCenter: parent.verticalCenter
                            clip: false

                            required property int index
                            property int slotIndex: index
                            // Slots 0-2 pin workspaces 1-3; slot 3 floats to
                            // the current workspace once it's ≥ 4.
                            property int wsId: slotIndex < 3 ? slotIndex + 1 : Math.max(4, workspacePanel.currentWsId)
                            property bool isActive: workspacePanel.currentWsId === wsId

                            Rectangle {
                                anchors.centerIn: parent
                                width: isActive ? 16 : 6
                                height: isActive ? 16 : 6
                                radius: isActive ? 8 : 3
                                color: Qt.rgba(1, 1, 1, isActive ? 0.15 : 0.8)
                                Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Behavior on color  { ColorAnimation  { duration: 200 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.parent.wsId
                                    color: "white"
                                    font.family: "Geist"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    opacity: parent.parent.isActive ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    onClicked: Hyprland.dispatch("workspace " + parent.parent.wsId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
