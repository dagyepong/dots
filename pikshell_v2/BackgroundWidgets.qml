import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.VectorImage
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl
import Quickshell.Services.Mpris


import Quickshell.Bluetooth

PanelWindow {

    id: background_panel


    property string preferredPlayer: ""

    property var player: {
        const list = Mpris.players.values;
        if (list.length === 0) return null;

        if (preferredPlayer.length > 0) {
            const match = list.find(p => p.identity && p.identity.toLowerCase().includes(preferredPlayer.toLowerCase()));
            if (match) return match;
        }

        const playing = list.find(p => p.playbackState === MprisPlaybackState.Playing);
        return playing || list[0];
    }

    implicitWidth: 436
    implicitHeight: 120

    property real displayPosition: player ? player.position : 0

    Timer {
        interval: 1000
        running: background_panel.player !== null && background_panel.player.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: background_panel.displayPosition = background_panel.player.position
    }

    Connections {
        target: background_panel.player
        function onPositionChanged() {
            background_panel.displayPosition = background_panel.player.position;
        }
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds)) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    anchors.top: island.bottom
    anchors.right: true
    anchors.left: true
    anchors.bottom: true
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "dynamic-island"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    exclusiveZone: 0

    property bool hovered: false

    Item {

        anchors.fill: parent


        Text{
            id: date_text_background
            text: Qt.formatTime(clock.date, "hh:mm")
            font.family: "SF Mono"
            color: "#ffffff"
            font.pixelSize: 75
            font.weight: 600
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.margins: 50
        }

        Slider {

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: background_music_rectangle.bottom
            anchors.margins: 10

            width: 400
            height: 10
            id: seekSlider
            Layout.fillWidth: true
            to: background_panel.player && background_panel.player.length > 0 ? background_panel.player.length : 1
            enabled: !!background_panel.player && background_panel.player.canSeek

            Binding {
                target: seekSlider
                property: "value"
                value: background_panel.displayPosition
                when: !seekSlider.pressed
            }

            onMoved: {
                    if (background_panel.player && background_panel.player.canSeek)
                        background_panel.player.position = value
                }

            background: ClippingRectangle {
                x: seekSlider.leftPadding
                y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                width: seekSlider.availableWidth
                height: 10
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: "#ffffff"
                Rectangle {
                    width: seekSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 8
                    color: "#ffffff"
                    Behavior on width {
                        NumberAnimation{duration: 500; easing.type: Easing.OutCubic}
                    }
                }
            }
            handle: null
        }

        Rectangle {
            id: album_art_rectangle
            anchors.centerIn: parent
            height: 350
            width: 350
            color : "transparent"

            radius: 20
            clip:true
            Image {
                id: albumArt
                anchors.fill: parent
                source: background_panel.player && background_panel.player.trackArtUrl ? background_panel.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                antialiasing: true
                asynchronous: true
            }
        }

        Rectangle {
            id: background_music_rectangle
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: album_art_rectangle.bottom
            anchors.margins: 20
            height: 70
            width: 400
            color: "transparent"
            border.width: 1
            border.color: "#ffffff"
            radius: 10
            clip:true
            ColumnLayout {
                anchors.centerIn: parent
                Text {
                    Layout.fillHeight: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: background_panel.player && background_panel.player.trackTitle ? background_panel.player.trackTitle : "No track"
                    color: "#ffffff"
                    font.pixelSize: 17
                    font.family: "SF Mono"
                    font.weight: 700
                    font.bold: true
                    elide: Text.ElideMiddle
                }

                Text {
                    Layout.fillHeight: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: background_panel.player && background_panel.player.trackArtists ? background_panel.player.trackArtists : ""
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.family: "SF Mono"
                    font.weight: 600
                    elide: Text.ElideMiddle
                }
            }
       }


        Item {
            id: visualizer

            width: 1920
            height: 200

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            property int barCount: 128         // must match cava's [general] bars
            property int maxRange: 1000        // must match cava's ascii_max_range (default 1000 if unset)
            property bool active: true         // tie to your widget's visibility
            property real smoothing: 0.35      // 0..1 — lower = floatier, higher = snappier
            property color lineColor: "#ffffff"
            property color fillTop: Qt.rgba(1, 1, 1, 1)
            property color fillBottom: Qt.rgba(1, 1, 1, 1)

            property var values: Array(barCount).fill(0)
            property var displayValues: Array(barCount).fill(0)

            Process {
                running: visualizer.active
                command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/cava.conf"]

                stdout: SplitParser {
                    onRead: data => {
                        if (!data) return
                        const nums = data.split(";").filter(s => s.length > 0).map(Number)
                        if (nums.length !== visualizer.barCount) return
                        visualizer.values = nums
                    }
                }

                stderr: SplitParser {
                    onRead: data => console.log("cava stderr:", data)
                }
            }

            Timer {
                interval: 16
                running: visualizer.active
                repeat: true
                onTriggered: {
                    const target = visualizer.values
                    const cur = visualizer.displayValues
                    const next = new Array(target.length)
                    for (let i = 0; i < target.length; i++) {
                        const c = cur[i] !== undefined ? cur[i] : target[i]
                        next[i] = c + (target[i] - c) * visualizer.smoothing
                    }
                    visualizer.displayValues = next
                    canvas.requestPaint()
                }
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                renderStrategy: Canvas.Threaded

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    const vals = visualizer.displayValues
                    const n = vals.length
                    if (n < 2) return

                    const step = width / (n - 1)
                    const points = []
                    for (let i = 0; i < n; i++) {
                        const v = Math.max(0, Math.min(visualizer.maxRange, vals[i])) / visualizer.maxRange
                        points.push({ x: i * step, y: height - v * height })
                    }

                    ctx.beginPath()
                    ctx.moveTo(points[0].x, points[0].y)
                    for (let i = 0; i < points.length - 1; i++) {
                        const p0 = points[i === 0 ? 0 : i - 1]
                        const p1 = points[i]
                        const p2 = points[i + 1]
                        const p3 = points[i + 2 < points.length ? i + 2 : i + 1]

                        const cp1x = p1.x + (p2.x - p0.x) / 6
                        const cp1y = p1.y + (p2.y - p0.y) / 6
                        const cp2x = p2.x - (p3.x - p1.x) / 6
                        const cp2y = p2.y - (p3.y - p1.y) / 6

                        ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y)
                    }

                    ctx.lineJoin = "round"
                    ctx.lineWidth = 2
                    ctx.strokeStyle = visualizer.lineColor
                    ctx.stroke()

                    ctx.lineTo(width, height)
                    ctx.lineTo(0, height)
                    ctx.closePath()
                    const gradient = ctx.createLinearGradient(0, 0, 0, height)
                    gradient.addColorStop(0, visualizer.fillTop)
                    gradient.addColorStop(1, visualizer.fillBottom)
                    ctx.fillStyle = gradient
                    ctx.fill()
                }
            }
        }
    }
}
