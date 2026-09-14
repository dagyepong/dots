// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   M O D U L E                                                │
// │   media · artwork and spectrum, full player when open                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The chip announces playback: artwork and a spectrum. The detail is the
// player: artwork, title, artist, progress and transport.
//
// The spectrum comes from cava, so it follows the actual audio and stops on
// silence. It is white because colour on the bar signals a level.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: {
        MediaService.subscribe()
        CavaService.subscribe()
    }
    Component.onDestruction: {
        MediaService.release()
        CavaService.release()
    }

    function clock(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(total / 60)
        const rest = total % 60
        return `${minutes}:${rest < 10 ? "0" : ""}${rest}`
    }

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // ── CHIP ────────────────────────────────────────────────────────────────

    // Ring face: the artwork as a disc inside a ring driven by loudness. The
    // title is the figure, drawn by `ChipFace`.
    Component {
        id: chip

        Item {
            id: chipRoot

            readonly property real artSize: Math.round(Theme.capsuleHeight * 0.62)

            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: MediaService.playing ? CavaService.level : 0
                    trackColor: Theme.indicatorDim
                    // White: loudness has no level worth colouring, unlike
                    // charge or a countdown.
                    fillColor: Theme.indicator
                    // Short enough to track the audio.
                    sweepDuration: 90
                }

                // ClippingRectangle, because `clip` is rectangular and would
                // square the artwork's corners.
                ClippingRectangle {
                    anchors.centerIn: parent
                    width: chipRoot.artSize
                    height: chipRoot.artSize
                    radius: width / 2
                    color: Theme.islandSurfaceHover

                    Image {
                        id: chipArt
                        anchors.fill: parent
                        source: MediaService.artUrl
                        visible: source != "" && status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 44
                        sourceSize.height: 44
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !chipArt.visible
                        text: "󰎇"
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(chipRoot.artSize * 0.55)
                        color: Theme.indicator
                    }
                }
            }
        }
    }

    // ── DETAIL ──────────────────────────────────────────────────────────────

    // No wrapper: this detail takes the island's full width, which a Loader
    // provides by resizing its item. Three bands: now playing, progress,
    // transport.
    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 10
            spacing: 10

            // ── NOW PLAYING ─────────────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                ClippingRectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: width * Theme.pictureCorner
                    color: Theme.islandSurfaceHover

                    Image {
                        id: art
                        anchors.fill: parent
                        source: MediaService.artUrl
                        visible: source != "" && status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 104
                        sourceSize.height: 104
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !art.visible
                        text: "󰎇"
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                        color: Theme.indicator
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    // The spectrum sits on the title's line; centred on the
                    // artwork it would fall between the two lines of text.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: MediaService.title !== "" ? MediaService.title : MediaService.identity
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Spectrum {
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            barWidth: 3
                            minimum: 2
                            active: MediaService.playing
                            barColor: Theme.indicator
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: MediaService.artist !== "" ? MediaService.artist : MediaService.identity
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            // ── PROGRESS ────────────────────────────────────────────────────

            // Hidden for streams, which have no length. The whole strip is the
            // hit area; the handle appears only on hover.
            Item {
                id: seek

                Layout.fillWidth: true
                Layout.preferredHeight: 20
                visible: MediaService.seekable

                readonly property real trackLeft: elapsedLabel.width + 10
                readonly property real trackRight: seek.width - lengthLabel.width - 10
                readonly property real trackWidth: Math.max(1, seek.trackRight - seek.trackLeft)

                Text {
                    id: elapsedLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.clock(MediaService.position)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                UsageBar {
                    id: track
                    x: seek.trackLeft
                    width: seek.trackWidth
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: seekMouse.containsMouse ? 6 : 4
                    progress: MediaService.progress
                    fillColor: Theme.indicator

                    Behavior on implicitHeight {
                        NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                    }
                }

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.indicator
                    visible: MediaService.canSeek && seekMouse.containsMouse
                    x: track.x + track.width * Math.max(0, Math.min(1, MediaService.progress)) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: lengthLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.clock(MediaService.length)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                MouseArea {
                    id: seekMouse

                    x: seek.trackLeft
                    width: seek.trackWidth
                    height: parent.height
                    hoverEnabled: true
                    enabled: MediaService.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: event => MediaService.seek(event.x / seek.trackWidth)
                    onPositionChanged: event => {
                        if (pressed)
                            MediaService.seek(event.x / seek.trackWidth)
                    }
                }
            }

            // ── TRANSPORT ───────────────────────────────────────────────────

            // Centred with anchors: spacers only centre when both sides are
            // equally wide. Round buttons with no background until hovered.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    IconButton {
                        icon: "󰒮"
                        iconSize: 17
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 17
                        enabled: MediaService.canPrevious
                        opacity: enabled ? 1 : 0.3
                        onClicked: MediaService.previous()
                    }

                    IconButton {
                        icon: MediaService.playing ? "󰏤" : "󰐊"
                        iconSize: 22
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 17
                        onClicked: MediaService.toggle()
                    }

                    IconButton {
                        icon: "󰒭"
                        iconSize: 17
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 17
                        enabled: MediaService.canNext
                        opacity: enabled ? 1 : 0.3
                        onClicked: MediaService.next()
                    }
                }
            }
        }
    }
}
