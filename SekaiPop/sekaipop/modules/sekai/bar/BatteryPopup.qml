import Quickshell.Services.UPower
import QtQuick
import "BatteryMath.js" as BM
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The card that drops down from BatteryIndicator.qml, redesigned as the Live's
// life gauge: a plate (SekaiPlate, the header all four bar popups share) that
// takes the colour of the judgement, the gauge on its own track, and the power
// mode as one connected switch. Same wiring as before (Bar.qml gives it `percentage`,
// `statusLabel` and `timeRemaining`); the frame, focus grab, pop-in and
// swallow come from SekaiPopup.qml.
//
//   The number    the charge as sticker numerals. It turns red-pink when you
//                 are low and not charging.
//   The stamp     a tilted judgement sticker, the way a song ends: ALL PERFECT
//                 (full and plugged in), PERFECT, GREAT, GOOD, BAD, MISS. The
//                 thresholds are BatteryMath.js tier(). Poke it for a puff of
//                 diamonds. Beside it, the status, with three beat diamonds
//                 that take turns while it charges.
//   The gauge     ten slanted segments that fill in one after another when the
//                 card opens. While charging, a pulse runs up them; when you are
//                 low it shakes once. SLIDE YOUR POINTER ALONG IT to forecast:
//                 the stamp shows the judgement of the level under the pointer,
//                 and the strip below says how long until the battery gets
//                 there at today's pace ("About 1h 05m from now at this pace").
//                 It is a straight line from what UPower reports, so treat it
//                 as a guess, not a promise.
//   The keys      the time left (or to full) on two keycaps, hours navy and
//                 minutes gradient, like the clock widget.
//   Power mode    Saver / Balanced / Boost as three keycaps; the one that is on
//                 sits pressed in. Boost only shows when the power profile
//                 daemon offers it.
SekaiPopup {
    id: root

    property int percentage: 0
    property string statusLabel: ""
    property string timeRemaining: ""

    readonly property bool charging: root.statusLabel === "Charging"
    readonly property bool full: root.statusLabel === "Fully charged"
    readonly property bool plugged: root.charging || root.full || root.statusLabel === "Plugged in"
    readonly property bool low: root.percentage <= 20 && !root.charging
    readonly property int minutes: BM.parseMins(root.timeRemaining)

    // What the pointer is doing on the gauge.
    readonly property bool scrubbing: scrub.containsMouse
    readonly property int scrubTarget: Math.max(0, Math.min(100,
        Math.round((scrub.mouseX - gauge.lean / 2) / Math.max(1, scrub.width - gauge.lean) * 100)))

    // The judgement on show: the real one, or the one for the level you point at.
    readonly property int shownPct: root.scrubbing ? root.scrubTarget : root.percentage
    readonly property int tierIdx: BM.tier(root.shownPct, root.plugged && !root.scrubbing)
    readonly property var tierFill: ["#FFE066", Theme.accentMint, "#FF9ECB", "#A5E6A5", "#B39DDB", "#e0575b"]

    readonly property string scrubText: {
        if (Math.abs(root.scrubTarget - root.percentage) <= 1)
            return "That's right about now"
        const e = BM.eta(root.percentage, root.scrubTarget, root.charging, root.minutes)
        if (e.kind === "eta")
            return "About " + BM.fmtMins(e.mins) + (root.charging ? " of charging to get there" : " from now at this pace")
        if (e.kind === "past")
            return "You're already past that"
        if (e.kind === "above")
            return "It needs a charger to climb back up there"
        return "No estimate yet"
    }

    readonly property int pad: 16
    readonly property int innerW: 304

    contentWidth: root.innerW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    // ===== the open / charging choreography =====
    property real fillWave: 1
    // The charging pulse runs from segment 0 up to the one being filled, then rests.
    property int sweepPhase: 0
    readonly property int frontier: Math.min(9, Math.floor(root.percentage / 10))
    property real shakeX: 0

    NumberAnimation {
        id: fillAnim
        target: root
        property: "fillWave"
        from: 0
        to: 1
        duration: 650
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: -6; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: 6; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: -4; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: 3; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 60 }
    }

    Timer {
        id: sweepTimer
        interval: 130
        repeat: true
        running: root.open && root.charging
        onTriggered: root.sweepPhase = (root.sweepPhase + 1) % (root.frontier + 3)
        onRunningChanged: {
            if (!running)
                root.sweepPhase = -1
        }
    }

    // The ALL PERFECT puff, a beat after the card has landed.
    Timer {
        id: celebrate
        interval: 380
        onTriggered: puff.fire()
    }

    onOpenChanged: {
        // Pressed again while the card was still going away: it turns round
        // instead of replaying the fill-in.
        if (open && root.reveal < 0.35) {
            fillAnim.restart()
            if (root.low)
                shakeAnim.restart()
            if (root.tierIdx === 0)
                celebrate.restart()
        }
    }

    onTierIdxChanged: stampPop.restart()

    Gradient {
        id: accentGradient
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    // The ink on the plate: dark, except on the red MISS plate.
    readonly property color plateInk: root.tierIdx === 5 ? Theme.textWhite : Theme.colBorder

    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.innerW
        spacing: 10

        // ===== the plate: the number and the judgement =====
        SekaiPlate {
            id: plate
            width: root.innerW
            height: 106
            // The plate wears the colour of the judgement (the accent
            // gradient for PERFECT), so the level reads before the number.
            colorTop: root.tierIdx === 1 ? Theme.accentMint : Qt.lighter(root.tierFill[root.tierIdx], 1.16)
            colorBottom: root.tierIdx === 1 ? Theme.accentCyan : root.tierFill[root.tierIdx]
            Behavior on colorTop { ColorAnimation { duration: 160 } }
            Behavior on colorBottom { ColorAnimation { duration: 160 } }

            StickerText {
                id: pctNum
                x: 6
                y: 5
                text: String(root.percentage)
                pixelSize: 56
                fillColor: plate.numberFill
                ringColor: plate.numberRing
            }

            // Tucked against the numerals (their box carries the outline and the
            // shadow, so it is pulled in by that much) and sat on their baseline.
            StickerText {
                x: pctNum.x + pctNum.width - 6
                y: 31
                text: "%"
                pixelSize: 24
                fillColor: plate.numberFill
                ringColor: plate.numberRing
            }

            // Status line: three beat diamonds (they take turns while charging) and the words.
            Row {
                x: 16
                y: 81
                spacing: 7

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    visible: root.plugged

                    Repeater {
                        model: 3

                        delegate: DiamondDot {
                            required property int index
                            size: 9
                            lit: root.charging ? (root.sweepPhase >= 0 && root.sweepPhase % 3 === index) : true
                            litColor: Theme.textWhite
                            offColor: Qt.rgba(1, 1, 1, 0.25)
                            lineColor: root.plateInk
                        }
                    }
                }

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: BM.glyph(root.percentage, root.charging)
                    fill: 0
                    size: 20
                    weight: 600
                    color: root.plateInk
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.statusLabel
                    color: root.plateInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }

            // The tilted judgement sticker.
            Text {
                id: stampProbe
                visible: false
                text: BM.word(root.tierIdx)
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                font.letterSpacing: 0.6
            }

            Pill {
                id: stamp
                width: stampProbe.implicitWidth + 38
                height: 42
                x: plate.width - stamp.width - 12
                y: 14
                shadowDx: 3
                shadowDy: 4
                cornerRadius: 13
                ringWidth: 4
                rotation: 6
                transformOrigin: Item.Center
                scale: stampPopValue
                pressed: stampArea.pressed
                fillColor: Theme.chipFill

                property real stampPopValue: 1

                Text {
                    anchors.centerIn: parent
                    text: BM.word(root.tierIdx)
                    color: Theme.dark ? (root.tierIdx === 5 ? "#ff8a92" : Theme.accentMint)
                                   : (root.tierIdx === 5 ? "#c93a40" : Theme.colBorder)
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 0.6
                }
            }

            NumberAnimation {
                id: stampPop
                target: stamp
                property: "stampPopValue"
                from: 1.3
                to: 1
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 2.6
            }

            MouseArea {
                id: stampArea
                x: stamp.x
                y: stamp.y
                width: stamp.width
                height: stamp.height
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    stampPop.restart()
                    puff.fire()
                }
            }

            Burst {
                id: puff
                x: stamp.x + stamp.width / 2
                y: stamp.y + stamp.height / 2
                radius: 60
            }
        }

        // ===== the life gauge =====
        Item {
            id: gaugeHead
            width: root.innerW
            height: 24

            SectionTab {
                text: "Life gauge"
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "slide along it to forecast"
                color: Theme.inkSub
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: track
            width: root.innerW
            height: 68
            radius: 18
            color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.28)
            border.width: 2
            border.color: Theme.line
            antialiasing: true

            Item {
                id: gauge
                x: 10 + root.shakeX
                y: 6
                width: track.width - 20
                height: 42

                readonly property int n: 10
                readonly property real segH: 36
                readonly property real skew: 0.2
                readonly property real lean: gauge.segH * gauge.skew
                readonly property real segW: 24 + gauge.lean
                readonly property real pitch: (gauge.width - gauge.segW) / (gauge.n - 1)

                Repeater {
                    model: gauge.n

                    delegate: Item {
                        id: seg
                        required property int index
                        x: seg.index * gauge.pitch
                        y: 3
                        width: gauge.segW
                        height: gauge.segH

                        readonly property real f: BM.segmentFill(root.percentage, seg.index, gauge.n)
                        readonly property real t: BM.clamp01((root.fillWave * 650 - seg.index * 45) / 250)
                        readonly property bool pulse: root.charging && root.sweepPhase === seg.index

                        // The charging pulse lifts a segment for a beat.
                        Item {
                            anchors.fill: parent
                            scale: seg.pulse ? 1.14 : 1
                            y: seg.pulse ? -3 : 0
                            Behavior on scale {
                                NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                            }
                            Behavior on y {
                                NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                            }

                            // The fill-in pops each segment up in turn.
                            Item {
                                anchors.fill: parent
                                scale: 0.8 + 0.2 * BM.outBack(seg.t, 2.2)
                                opacity: Math.min(1, seg.t * 3)

                                Slant {
                                    anchors.fill: parent
                                    skew: gauge.skew
                                    radius: 9
                                    color: Theme.surfaceHover
                                    borderColor: Theme.line
                                    borderWidth: 3
                                }

                                // The charge in this segment. A part-full one is a
                                // narrower slant filling from the left, at full colour.
                                Slant {
                                    height: parent.height
                                    width: seg.f >= 1 ? parent.width
                                        : gauge.lean + Math.max(12, (parent.width - gauge.lean) * seg.f)
                                    skew: gauge.skew
                                    radius: 9
                                    color: root.low ? "#e0575b" : "transparent"
                                    gradient: root.low ? null : accentGradient
                                    borderColor: Theme.line
                                    borderWidth: 3
                                    opacity: seg.f > 0 ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation { duration: 160 }
                                    }
                                    Behavior on width {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }
                }

                // The scrub playhead.
                Rectangle {
                    visible: root.scrubbing
                    x: Math.max(0, Math.min(gauge.width - width, scrub.mouseX - width / 2))
                    y: -1
                    width: 3
                    height: gauge.height + 2
                    radius: 1.5
                    color: Theme.ink
                }

                MouseArea {
                    id: scrub
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                }
            }

            // The scale under the gauge.
            Repeater {
                model: [ { v: "0", at: 0 }, { v: "50", at: 0.5 }, { v: "100", at: 1 } ]

                delegate: Text {
                    required property var modelData
                    x: 10 + modelData.at * (track.width - 20) - width * modelData.at
                    y: 51
                    text: modelData.v
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }

        // ===== the time =====
        Item {
            id: readout
            width: root.innerW
            height: 56

            Row {
                id: timeRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                opacity: !root.scrubbing && root.minutes > 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }

                Pill {
                    id: hourKey
                    visible: root.minutes >= 60
                    width: 52
                    height: 46
                    shadowDy: 4
                    cornerRadius: 14
                    ringWidth: 4
                    fillColor: Theme.chipFill

                    Text {
                        anchors.centerIn: parent
                        text: String(Math.floor(root.minutes / 60))
                        color: Theme.chipInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Text {
                    visible: hourKey.visible
                    anchors.verticalCenter: parent.verticalCenter
                    text: "h"
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Pill {
                    width: 52
                    height: 46
                    shadowDy: 4
                    cornerRadius: 14
                    ringWidth: 4
                    fillGradient: accentGradient

                    Text {
                        anchors.centerIn: parent
                        text: ((root.minutes % 60) < 10 ? "0" : "") + (root.minutes % 60)
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "m"
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 6
                    spacing: 1

                    Text {
                        text: root.charging ? "until full" : "remaining"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                    Text {
                        text: "at the pace it has now"
                        color: Theme.inkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            // No pace to read yet (just plugged in, or full): the same key
            // + two lines as the time above, so it is never just a line of text.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                opacity: !root.scrubbing && root.minutes <= 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }

                Pill {
                    width: 46
                    height: 46
                    shadowDy: 4
                    cornerRadius: 14
                    ringWidth: 4
                    fillColor: Theme.chipFill

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: root.full ? "battery_full" : (root.plugged ? "power" : "hourglass_empty")
                        fill: 0
                        size: 24
                        weight: 600
                        color: Theme.chipInk
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.innerW - 46 - 10
                    spacing: 1

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.full ? "Topped up"
                            : (root.plugged ? "Plugged in" : "Working it out…")
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.full ? "Unplug whenever you like."
                            : (root.plugged ? "Not charging right now."
                                            : "Waiting for a reading of the pace.")
                        color: Theme.inkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            // The forecast.
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 2
                opacity: root.scrubbing ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }

                Text {
                    text: "At " + root.scrubTarget + "%"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.scrubText
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }

        // ===== power mode: one connected switch =====
        SectionTab {
            text: "Power mode"
        }

        Rectangle {
            id: modes
            width: root.innerW
            height: 56
            radius: 18
            color: Theme.surfaceHover
            border.width: 3
            border.color: Theme.line
            antialiasing: true

            readonly property var defs: [
                { icon: "eco", label: "Saver", profile: PowerProfile.PowerSaver },
                { icon: "balance", label: "Balanced", profile: PowerProfile.Balanced },
                { icon: "rocket_launch", label: "Boost", profile: PowerProfile.Performance }
            ]
            readonly property var shown: PowerProfiles.hasPerformanceProfile ? modes.defs : modes.defs.slice(0, 2)
            readonly property real slot: (modes.width - 6) / modes.shown.length
            readonly property int activeIndex: {
                for (let i = 0; i < modes.shown.length; i++)
                    if (modes.shown[i].profile === PowerProfiles.profile)
                        return i
                return -1
            }

            // The thumb that slides under the chosen mode.
            Rectangle {
                visible: modes.activeIndex >= 0
                y: 3
                width: modes.slot
                height: modes.height - 6
                x: 3 + Math.max(0, modes.activeIndex) * modes.slot
                radius: 15
                gradient: accentGradient
                border.width: 3
                border.color: Theme.line
                antialiasing: true
                Behavior on x {
                    NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                }
            }

            Repeater {
                model: modes.shown

                delegate: Item {
                    id: modeKey
                    required property var modelData
                    required property int index
                    readonly property bool active: modes.activeIndex === index
                    x: 3 + index * modes.slot
                    width: modes.slot
                    height: modes.height

                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modeKey.modelData.icon
                            fill: 0
                            size: 20
                            weight: 600
                            color: modeKey.active ? Theme.colBorder : Theme.ink
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modeKey.modelData.label
                            color: modeKey.active ? Theme.colBorder : Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = modeKey.modelData.profile
                    }
                }
            }
        }
    }
}
