// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   F A C E                                                        │
// │   one creature, drawn · egg, coat, ears, mood                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// One pet, drawn from shapes in its species' palette token. The record and
// mood are properties rather than read from PetService because the shelf and
// settings draw the whole family at once.
//
// Egg until hatched (speckled in its future colour); ears at level 5, a star
// at level 15.
Item {
    id: root

    property var record: PetService.pet
    property string mood: PetService.mood
    property real size: 40
    property bool lively: false

    readonly property bool egg: !(root.record && root.record.hatchedAt > 0)
    readonly property int level: root.record ? root.record.level : 1
    readonly property bool asleep: root.mood === "asleep"
    readonly property var kind: PetService.speciesOf(root.record)

    readonly property color coat: ({
        accent: Theme.accent,
        green: Theme.green,
        yellow: Theme.yellow,
        red: Theme.red,
        blue: Theme.blue
    })[root.kind.tint] ?? Theme.accent

    property real blink: 1

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size

    // Blink timing is part of the character, not a motion token.
    SequentialAnimation {
        running: root.lively && !root.asleep && !root.egg
        loops: Animation.Infinite

        PauseAnimation { duration: 2800 }
        NumberAnimation { target: root; property: "blink"; to: 0.15; duration: 70 }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 110 }
    }

    // ── THE EGG ─────────────────────────────────────────────────────────────

    Rectangle {
        visible: root.egg
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.size * 0.72
        height: root.size * 0.92
        topLeftRadius: width * 0.52
        topRightRadius: width * 0.52
        bottomLeftRadius: width * 0.42
        bottomRightRadius: width * 0.42
        color: Theme.indicator

        Rectangle {
            x: parent.width * 0.22
            y: parent.height * 0.30
            width: root.size * 0.09
            height: width
            radius: width / 2
            color: root.coat
        }

        Rectangle {
            x: parent.width * 0.58
            y: parent.height * 0.46
            width: root.size * 0.07
            height: width
            radius: width / 2
            color: root.coat
        }

        Rectangle {
            x: parent.width * 0.34
            y: parent.height * 0.64
            width: root.size * 0.08
            height: width
            radius: width / 2
            color: root.coat
        }
    }

    // ── EARS ────────────────────────────────────────────────────────────────

    // Drawn behind the head, shaped per species (`kind.ears`); Sol has none.
    readonly property bool eared: !root.egg && root.level >= 5

    Rectangle {
        visible: root.eared && root.kind.ears === "round"
        x: root.size * 0.10
        y: root.size * 0.02
        width: root.size * 0.24
        height: root.size * 0.24
        radius: width / 2
        color: root.coat
    }

    Rectangle {
        visible: root.eared && root.kind.ears === "round"
        x: root.size * 0.66
        y: root.size * 0.02
        width: root.size * 0.24
        height: root.size * 0.24
        radius: width / 2
        color: root.coat
    }

    Rectangle {
        visible: root.eared && root.kind.ears === "leaf"
        x: root.size * 0.14
        y: -root.size * 0.02
        width: root.size * 0.20
        height: root.size * 0.20
        rotation: 45
        radius: root.size * 0.04
        color: root.coat
    }

    Rectangle {
        visible: root.eared && root.kind.ears === "leaf"
        x: root.size * 0.66
        y: -root.size * 0.02
        width: root.size * 0.20
        height: root.size * 0.20
        rotation: 45
        radius: root.size * 0.04
        color: root.coat
    }

    Rectangle {
        visible: root.eared && root.kind.ears === "tuft"
        x: root.size * 0.40
        y: -root.size * 0.02
        width: root.size * 0.20
        height: root.size * 0.20
        radius: width / 2
        color: root.coat
    }

    Rectangle {
        visible: root.eared && root.kind.ears === "tuft"
        x: root.size * 0.46
        y: -root.size * 0.11
        width: root.size * 0.10
        height: root.size * 0.10
        radius: width / 2
        color: root.coat
    }

    Rectangle {
        visible: root.eared && root.kind.ears === "droop"
        x: -root.size * 0.03
        y: root.size * 0.30
        width: root.size * 0.15
        height: root.size * 0.32
        radius: width / 2
        color: root.coat
    }

    Rectangle {
        visible: root.eared && root.kind.ears === "droop"
        x: root.size * 0.88
        y: root.size * 0.30
        width: root.size * 0.15
        height: root.size * 0.32
        radius: width / 2
        color: root.coat
    }

    // Head.
    Rectangle {
        visible: !root.egg
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.size
        height: root.size * root.kind.aspect
        radius: height * 0.5
        color: root.coat
    }

    // Level-15 star, in a fixed indicator colour.
    Text {
        visible: !root.egg && root.level >= 15
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: -root.size * 0.06
        text: "★"
        font.pixelSize: Math.round(root.size * 0.26)
        color: Theme.indicatorWarn
    }

    // Eyes. A Scale transform because `scale` is uniform and a blink is
    // vertical only; Scale is not an Item, so the eyes are referenced by id.
    readonly property real lid: root.asleep ? 0.18 : root.blink

    Rectangle {
        id: leftEye
        visible: !root.egg
        x: root.size * 0.26
        y: root.size * 0.42
        width: root.size * 0.11
        height: root.size * 0.18
        radius: width / 2
        color: Theme.island
        transform: Scale {
            origin.y: leftEye.height / 2
            yScale: root.lid
        }
    }

    Rectangle {
        id: rightEye
        visible: !root.egg
        x: root.size * 0.63
        y: root.size * 0.42
        width: root.size * 0.11
        height: root.size * 0.18
        radius: width / 2
        color: Theme.island
        transform: Scale {
            origin.y: rightEye.height / 2
            yScale: root.lid
        }
    }

    // Mouth, by mood. The smile is flat on top and round below.
    Rectangle {
        visible: !root.egg
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.size * 0.67
        width: {
            switch (root.mood) {
            case "beaming": return root.size * 0.34
            case "peckish": return root.size * 0.26
            case "lonely":  return root.size * 0.12
            case "asleep":  return root.size * 0.16
            }
            return root.size * 0.22
        }
        height: {
            switch (root.mood) {
            case "beaming": return root.size * 0.15
            case "peckish": return root.size * 0.05
            case "lonely":  return root.size * 0.12
            case "asleep":  return root.size * 0.05
            }
            return root.size * 0.07
        }
        readonly property bool smiling: root.mood === "beaming"
        topLeftRadius: smiling ? height * 0.25 : height / 2
        topRightRadius: smiling ? height * 0.25 : height / 2
        bottomLeftRadius: height / 2
        bottomRightRadius: height / 2
        color: Theme.island

        Behavior on width {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
    }

    Text {
        visible: root.asleep && !root.egg && root.lively
        anchors.left: parent.right
        anchors.leftMargin: -root.size * 0.14
        anchors.top: parent.top
        text: "z"
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.size * 0.24)
        color: Theme.textMuted
    }
}
