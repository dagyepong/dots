import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The media widget, matching the Figma "Media (Nothing Playing)" and
// "Media (Playing)" frames:
//
//   [ album art | divider |   Title (bold)   ]
//   [           |         |   Artist (light)  ]
//
// Pure UI (no Quickshell imports): Bar.qml -> Status_Bar.qml feed it
// plain properties and turn its signals into actions.
//
//   active   false -> single centered "Nothing Playing"
//            true  -> title, plus the artist underneath when there is one
//   playing  false while paused -> the content dims, the pill stays put
//
// Width follows the text (never below minWidth, never above maxWidth —
// Status_Bar sets maxWidth so this can't run into its neighbours), and
// long titles elide inside that.
//
// Click: left = play/pause, right = next track, middle = previous.
//
// Notifications used to take this pill over while one was showing; they
// now alert on the Quick Panel's phone instead (see QuickPanel.qml), so
// this file is just the media widget.
Pill {
    id: root

    // True on a standing bar (left / right edge): there isn't room for
    // text, so the pill becomes a small square with just the album art
    // (or the media icon). Click, right-click and middle-click work the
    // same.
    property bool vertical: false

    property bool active: false
    property bool playing: false
    property string title: ""
    property string artist: ""
    property string artUrl: ""

    // end4-pC's little visualizers, inside the pill (Settings -> Desktop -> "Media pill
    // visualizer"): "none", "dots" (PillBars.qml) or "wave" (PillWave.qml). `points` are
    // cava's bands (PcCavaService.qml). Never on a standing bar.
    property string visualizerStyle: "none"
    property var points: []
    readonly property bool showViz: !root.vertical && root.active && root.visualizerStyle !== "none"
    readonly property real vizWidth: root.visualizerStyle === "wave" ? 40 : 18
    readonly property real vizReserve: root.showViz ? root.vizWidth + 6 : 0

    // The Figma "Media Asset", shown in the art slot when nothing is
    // playing or the player sends no cover art.
    property string mediaIcon: "genres"   // Material Symbols Rounded name

    property real minWidth: 220
    property real maxWidth: 360

    property int titleSize: Theme.fontSizeTitle
    property int artistSize: Theme.fontSizeSub
    property int idleSize: Theme.fontSizeIdle

    // true: a left click opens the media panel (middle click plays / pauses);
    // false: the old clicks (left plays / pauses, middle goes back).
    property bool leftOpensPanel: true
    // The wheel over the pill (volume of the player); false stops reacting.
    property bool wheelVolume: true
    property bool volumeAvailable: false

    signal toggleRequested()
    signal nextRequested()
    signal previousRequested()
    signal panelRequested()
    // +1 for a notch up, -1 for a notch down.
    signal scrolled(int direction)

    // playing/title are a live reflection of the real MPRIS player
    // state (see MediaSource.qml) — they update the same way whether
    // play/pause/next/previous was triggered by clicking this pill or
    // by a keyboard media key (or another app's own controls) that
    // never touched this widget at all. Watch for that and pulse the
    // pill itself: a quick programmatic press-then-pop, same
    // animation a click gives, so it visually "presses" in sync with
    // whatever just happened to actually change playback.
    property bool keyPulse: false

    // Swallows that auto-pulse for a moment right after THIS pill was
    // the one physically clicked — the real MouseArea press/release
    // below already gave it tactile feedback, so there's no need to
    // pulse it a second time once the player confirms a beat later.
    property bool suppressPulse: false

    onPlayingChanged: externalPulse()
    onTitleChanged: externalPulse()

    function externalPulse() {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90 // matches Pill's press-down leg, so it lets go right as the push-in finishes
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 400 // covers the round-trip to the player and back
        onTriggered: root.suppressPulse = false
    }

    // Art block geometry, from the Figma frame (fill is 26px tall).
    // (Capsule bar: no cover art or divider; a small glyph stands in for the art, and
    // the title is one line of the chip's own ink.)
    readonly property real artWidth: root.capsule ? 24 : 35
    readonly property real dividerWidth: root.capsule ? 0 : 2
    readonly property real textMargin: 10
    readonly property color ink: root.capsule ? Theme.capInk : Theme.colBorder

    cornerRadius: Theme.radiusBadge
    ringWidth: 5
    fillColor: Theme.surface

    readonly property Gradient mediaGradient: Gradient {
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }
    fillGradient: mediaGradient

    // Physical press, same as the workspace badges: pushes flush
    // into its own shadow on mouse-down, pops back on release.
    // Combines the real MouseArea press below with the auto-pulse
    // above, so it looks the same whether a human clicked it or a
    // media key changed playback. "enabled: root.active" on
    // mediaArea below already means the click half of this never
    // fires while there's nothing to click.
    pressed: mediaArea.pressed || root.keyPulse

    implicitWidth: artWidth + dividerWidth + textMargin * 2 + root.vizReserve
        + Math.max(titleText.implicitWidth, artistText.visible ? artistText.implicitWidth : 0)
    width: root.vertical ? (root.capsule ? Theme.capVChip : Theme.barVPillWidth - 4) : Math.max(minWidth, Math.min(maxWidth, implicitWidth))
    // Standing bar: as tall as it is wide (plus the shadow), so the art
    // is square.
    // (Capsule: a round chip with the media glyph in it.)
    implicitHeight: root.vertical ? (root.capsule ? Theme.capVChip : Theme.barVPillWidth - 4) + Theme.shadowOffset
                                  : Theme.pillHeight + Theme.shadowOffset

    Behavior on width {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // Paused: the art and text dim, the pill's frame stays solid.
    readonly property real dim: root.active && !root.playing ? 0.55 : 1.0

    // Everything below lives in the colored fill.
    Item {
        id: body
        anchors.fill: parent

        // ===== album art =====
        Item {
            id: art
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.vertical ? parent.width : root.artWidth

            Item {
                id: artInner
                width: parent.width
                height: parent.height

                // The Media Asset -> cover art, stacked. Both square; the
                // rounded left corners are put back by the frame overlay
                // further down.
                Item {
                    id: artContent
                    anchors.fill: parent
                    opacity: root.dim

                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    // Nothing playing (or no cover art): the Media Asset icon
                    // straight on the pill's own color.
                    MaterialIcon {
                        color: root.ink
                        anchors.centerIn: parent
                        size: 22
                        name: root.mediaIcon
                    }

                    Image {
                        id: cover
                        anchors.fill: parent
                        // Nothing playing -> no cover art, the Media Asset shows.
                        source: root.active ? root.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        sourceSize: Qt.size(Math.max(1, art.width) * 2, Math.max(1, art.height) * 2)
                        // Don't reuse a stale image when a player rewrites
                        // the same cover file for the next track.
                        cache: false
                        visible: status === Image.Ready && !root.capsule

                        onStatusChanged: {
                            if (status === Image.Error)
                                console.warn("MediaPill: couldn't load cover art from " + source)
                        }
                    }
                }

                // Rounded corners without masking: redraw the pill's own
                // frame (white ring, then the navy outline — the very same
                // two rounded Rectangles Pill.qml draws) on top of the art,
                // clipped to the art's box. Where the square art overhangs
                // the curve, the frame covers it again, and because it's
                // the same primitive as the pill itself the corners are
                // exactly as smooth as the rest of the outline. The frame
                // is made much wider than the art so its right-hand
                // corners fall outside the clip and the art's right edge
                // stays square against the divider.
                Item {
                    anchors.fill: parent
                    clip: true
                    // (The frame redraws the pill's outline over the cover art; a chip has none.)
                    visible: !root.capsule

                    Rectangle {
                        x: -root.ringWidth
                        y: -root.ringWidth
                        // Flat bar: much wider than the art, so the right-hand
                        // corners fall outside the clip. Standing bar: exactly
                        // the whole pill, so all four corners show.
                        width: root.vertical ? art.width + root.ringWidth * 2
                                             : root.artWidth + root.cornerRadius * 4
                        height: parent.height + root.ringWidth * 2
                        radius: root.cornerRadius
                        color: "transparent"
                        border.width: root.ringWidth
                        border.color: Theme.ringWhite
                        antialiasing: true
                    }
                    Rectangle {
                        x: -root.ringWidth
                        y: -root.ringWidth
                        // Flat bar: much wider than the art, so the right-hand
                        // corners fall outside the clip. Standing bar: exactly
                        // the whole pill, so all four corners show.
                        width: root.vertical ? art.width + root.ringWidth * 2
                                             : root.artWidth + root.cornerRadius * 4
                        height: parent.height + root.ringWidth * 2
                        radius: root.cornerRadius
                        color: "transparent"
                        border.width: Theme.borderWidth
                        border.color: Theme.line
                        antialiasing: true
                    }
                }
            }
        }

        // ===== divider =====
        Rectangle {
            id: divider
            visible: !root.vertical && !root.capsule
            anchors.left: art.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.dividerWidth
            color: Theme.surface
        }

        // ===== text =====
        Item {
            visible: !root.vertical
            anchors.left: divider.right
            anchors.leftMargin: root.textMargin
            anchors.right: parent.right
            anchors.rightMargin: root.textMargin + root.vizReserve
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 1
                opacity: root.dim
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Text {
                    id: titleText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.active ? root.title : "Nothing Playing"
                    color: root.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: root.capsule ? Theme.fontSizeInfo : (root.active ? root.titleSize : root.idleSize)
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    id: artistText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: root.active && root.artist !== "" && !root.capsule
                    text: root.artist
                    color: Theme.colSubText
                    font.family: Theme.fontFamily
                    font.pixelSize: root.artistSize
                    font.weight: Font.Medium
                }
            }
        }

        // ===== visualizer (end4-pC's) =====
        Loader {
            anchors.right: parent.right
            anchors.rightMargin: root.textMargin
            anchors.verticalCenter: parent.verticalCenter
            width: root.vizWidth
            height: root.capsule ? 14 : 22
            active: root.showViz
            opacity: root.dim
            sourceComponent: root.visualizerStyle === "wave" ? waveComp : dotsComp
        }

        Component {
            id: waveComp
            PillWave {
                points: root.points
                live: root.playing
                color: root.ink
                fillAlpha: 0.35
            }
        }

        Component {
            id: dotsComp
            PillBars {
                points: root.points
                live: root.playing
                contentColor: root.ink
                barCount: 3
                maxBarHeight: root.capsule ? 14 : 22
            }
        }

        // "Scroll for volume", when this player has a volume.
        ScrollHint {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -8
            anchors.rightMargin: -8
            active: root.active && root.wheelVolume && root.volumeAvailable && !root.capsule
            glyph: "volume_up"
        }

        // Covers the whole pill (ring included), not just the fill —
        // hence the negative margins.
        MouseArea {
            id: mediaArea
            anchors.fill: parent
            anchors.margins: -root.ringWidth
            enabled: root.active
            cursorShape: root.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    if (root.leftOpensPanel)
                        root.panelRequested()
                    else
                        root.toggleRequested()
                } else if (mouse.button === Qt.RightButton) {
                    root.nextRequested()
                } else if (mouse.button === Qt.MiddleButton) {
                    if (root.leftOpensPanel)
                        root.toggleRequested()
                    else
                        root.previousRequested()
                }
            }
            onWheel: wheel => {
                if (!root.wheelVolume || wheel.angleDelta.y === 0) {
                    wheel.accepted = false
                    return
                }
                root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
            }
            onPressed: root.suppressPulse = true
            onReleased: suppressGrace.restart()
            onCanceled: suppressGrace.restart()
        }
    }
}
