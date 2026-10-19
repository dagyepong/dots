import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The content of the OSD (on-screen-display) popup: whichever of volume / mic /
// brightness / gamma just changed, on a SekaiPlate (the slab every bar popup
// opens with) sitting inside the same housing the bar, the dock and the
// keyboard have: navy outline -> the wide pale ring (Theme.surfaceRing, white
// in Dark) -> surface, on a hard shadow straight down. A small cousin of the
// Battery popup's life gauge:
//
//   [ [ (key) VOLUME                  45 % ] ]
//   [ [ ▰▰▰▰▱▱▱▱▱▱   ten slanted segments  ] ]
//
//   The key      the icon on a keycap (a Pill in the chip colours, like the
//                judgement stamp). It dips and springs back when the kind
//                changes or the mute flips, like a real key being hit.
//   The number   the level as sticker numerals (dark fill, white ring, the
//                plate's own `numberFill` / `numberRing`). It hops up a
//                little on every change, the way a note is hit.
//   The gauge    ten slanted segments, lit white on a dim slot. A part-full
//                one fills from the left, so a 5 % step shows as half a
//                segment. The segment at the front of the fill lifts for a
//                beat on every change (the charging pulse of the Battery
//                gauge, played once per step).
//   The plate    wears the colour of the state, like the Battery plate wears
//                the judgement: the accent gradient normally, lavender while
//                muted (the number turns into a tilted MUTE stamp and the
//                gauge keeps the level as a ghost), pink above 100 %.
//
// Pure UI: OSDPopup.qml (the window) feeds this `kind`/`value`/`muted` and
// never touches OSDSource.qml itself. Careful with coordinates: whatever is
// declared inside a Pill lands in its `fill`, which is already inset by the
// ring, so the plate is placed from (padding, padding) and its own content
// from the plate's top-left corner ((0, 0); the face is 88 tall).
Pill {
    id: root

    property string kind: "volume"   // "volume" | "mic" | "brightness" | "gamma"
    property real value: 0           // 0-100 (volume can be pushed past 100)
    property bool muted: false

    readonly property string iconName: {
        if (kind === "brightness")
            return "brightness_6"
        if (kind === "gamma")
            return "contrast"
        if (kind === "mic")
            return muted ? "mic_off" : "mic"
        if (muted)
            return "volume_off"
        return value < 34 ? "volume_down" : "volume_up"
    }

    readonly property string labelText: {
        if (kind === "brightness") return "Brightness"
        if (kind === "gamma") return "Gamma"
        if (kind === "mic") return "Microphone"
        return "Volume"
    }

    // Brightness and gamma have no mute state to show — "muted" only
    // ever applies to volume/mic.
    readonly property bool showsMuted: root.muted && root.kind !== "brightness" && root.kind !== "gamma"
    // Past 100 % (a boosted sink): the gauge is full, the number says the truth.
    readonly property bool over: !root.showsMuted && root.value > 100.5
    // What the gauge draws: 0..100.
    readonly property real shown: Math.max(0, Math.min(100, root.value))

    // The ink on the plate: dark, like every plate's icon and name.
    readonly property color plateInk: Theme.colBorder

    readonly property color mutedColor: "#B39DDB"
    readonly property color overColor: "#FF9ECB"

    // ===== the housing: the bar's / dock's look =====
    readonly property real pad: 6
    readonly property real plateW: 288
    readonly property real plateFace: 88

    // outline + the wide pale ring; the plate sits `pad` inside it. The room
    // inside the ring is the plate, its hard shadow, and `pad` all round.
    cornerRadius: 28
    ringWidth: Theme.borderWidth + Theme.outerRingWidth
    ringColorTop: Theme.surfaceRing
    ringColorBottom: Theme.surfaceRing
    fillColor: Theme.surface
    shadowDx: 0
    shadowDy: Theme.shadowOffset
    width: root.plateW + 2 * root.pad + 2 * root.ringWidth
    height: root.plateFace + Theme.shadowOffset + 2 * root.pad + 2 * root.ringWidth + root.shadowDy

    // ===== the hits =====
    // The plate dips onto its shadow and springs back (Pill's own press
    // animation) when something other than the level changes.
    property bool pulse: false

    function hit() {
        root.pulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90 // Pill's press-down leg
        onTriggered: root.pulse = false
    }

    onKindChanged: root.hit()
    onShowsMutedChanged: {
        root.hit()
        if (root.showsMuted)
            stampPop.restart()
    }

    // Every change of the level: the numerals hop and the front segment lifts.
    property bool bump: false

    Timer {
        id: bumpRelease
        interval: 110
        onTriggered: root.bump = false
    }

    onValueChanged: {
        root.bump = true
        bumpRelease.restart()
        numberHop.restart()
    }

    NumberAnimation {
        id: numberHop
        target: readout
        property: "scale"
        from: 1.14
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    SekaiPlate {
        id: plate
        x: root.pad
        y: root.pad
        width: root.plateW
        height: root.plateFace + Theme.shadowOffset
        pressed: root.pulse

        colorTop: root.showsMuted ? Qt.lighter(root.mutedColor, 1.16)
            : (root.over ? Qt.lighter(root.overColor, 1.16) : Theme.accentMint)
        colorBottom: root.showsMuted ? root.mutedColor
            : (root.over ? root.overColor : Theme.accentCyan)
        Behavior on colorTop { ColorAnimation { duration: 160 } }
        Behavior on colorBottom { ColorAnimation { duration: 160 } }

        // ===== the key =====
        Pill {
            id: badge
            x: 12
            y: 10
            width: 40
            height: 40 + shadowDy
            cornerRadius: 14
            ringWidth: 3
            shadowDx: 0
            shadowDy: 3
            fillColor: Theme.chipFill
            pressed: root.pulse

            MaterialIcon {
                anchors.centerIn: parent
                name: root.iconName
                size: 22
                weight: 600
                color: Theme.chipInk
            }
        }

        // ===== the name =====
        Text {
            x: 62
            y: badge.y + 20 - implicitHeight / 2
            text: root.labelText.toUpperCase()
            color: root.plateInk
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            font.letterSpacing: 1.2
        }

        // ===== the number =====
        Item {
            id: readout
            visible: !root.showsMuted
            width: num.width + unit.width - 6
            height: num.height
            x: plate.width - 10 - readout.width
            y: badge.y + 20 - readout.height / 2

            StickerText {
                id: num
                text: String(Math.round(root.value))
                pixelSize: 36
                popOnChange: false
                fillColor: plate.numberFill
                ringColor: plate.numberRing
            }

            // Tucked against the numerals and sat on their baseline.
            StickerText {
                id: unit
                x: num.width - 6
                y: 15
                text: "%"
                pixelSize: 16
                popOnChange: false
                fillColor: plate.numberFill
                ringColor: plate.numberRing
            }
        }

        // ===== the MUTE stamp (in place of the number) =====
        Text {
            id: stampProbe
            visible: false
            text: "MUTE"
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            font.letterSpacing: 0.6
        }

        Pill {
            id: stamp
            visible: root.showsMuted
            width: stampProbe.implicitWidth + 34
            height: 38
            x: plate.width - 12 - stamp.width
            y: badge.y + 20 - (stamp.height - shadowDy) / 2
            shadowDx: 3
            shadowDy: 4
            cornerRadius: 12
            ringWidth: 4
            rotation: 6
            transformOrigin: Item.Center
            scale: stamp.popValue
            fillColor: Theme.chipFill

            property real popValue: 1

            Text {
                anchors.centerIn: parent
                text: "MUTE"
                color: Theme.dark ? "#ff8a92" : "#c93a40"
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                font.letterSpacing: 0.6
            }
        }

        NumberAnimation {
            id: stampPop
            target: stamp
            property: "popValue"
            from: 1.3
            to: 1
            duration: 380
            easing.type: Easing.OutBack
            easing.overshoot: 2.6
        }

        // ===== the gauge =====
        Item {
            id: gauge
            x: 12
            y: 58
            width: plate.width - 24
            height: 20

            readonly property int n: 10
            readonly property real skew: 0.2
            readonly property real lean: gauge.height * gauge.skew
            readonly property real segW: 22 + gauge.lean
            readonly property real pitch: (gauge.width - gauge.segW) / (gauge.n - 1)
            // The segment at the front of the fill: the one that lifts on a change.
            readonly property int front: Math.max(0, Math.min(gauge.n - 1, Math.ceil(root.shown / 100 * gauge.n) - 1))

            Repeater {
                model: gauge.n

                delegate: Item {
                    id: seg
                    required property int index

                    x: seg.index * gauge.pitch
                    width: gauge.segW
                    height: gauge.height

                    // How much of this segment the level fills: 0..1.
                    readonly property real f: Math.max(0, Math.min(1, root.shown / 100 * gauge.n - seg.index))
                    readonly property bool lifted: root.bump && root.shown > 0 && seg.index === gauge.front

                    scale: seg.lifted ? 1.16 : 1
                    y: seg.lifted ? -2 : 0
                    Behavior on scale {
                        NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                    }
                    Behavior on y {
                        NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                    }

                    // The dim slot.
                    Slant {
                        anchors.fill: parent
                        skew: gauge.skew
                        radius: 7
                        color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.28)
                        borderColor: Theme.line
                        borderWidth: 2
                    }

                    // The level in this segment. A part-full one is a narrower
                    // slant filling from the left, at full colour.
                    Slant {
                        height: parent.height
                        width: seg.f >= 1 ? parent.width
                            : gauge.lean + Math.max(8, (parent.width - gauge.lean) * seg.f)
                        skew: gauge.skew
                        radius: 7
                        color: Theme.textWhite
                        borderColor: Theme.line
                        borderWidth: 2
                        opacity: seg.f > 0 ? (root.showsMuted ? 0.5 : 1) : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}
