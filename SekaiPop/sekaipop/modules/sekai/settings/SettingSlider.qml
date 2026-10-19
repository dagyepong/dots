import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// A labelled slider for a number with a range (gaps, opacity, how long
// something waits). It is drawn like a rhythm game's lane: a leaning track
// with beat ticks under it, an accent fill that runs up to a diamond knob,
// and the value in a small leaning badge that lights up while you drag.
//
// Pure UI: `value` goes in, moved(value) comes out while you drag, already
// rounded to `step`. Dragging follows the pointer directly; `value` only
// has to catch up afterwards.
Item {
    id: root

    property string label: ""
    property string icon: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    // Shown instead of the number at one value (e.g. 0 -> "Off").
    property real specialValue: NaN
    property string specialText: ""

    signal moved(real value)

    implicitWidth: 360
    implicitHeight: 72

    property bool dragging: false
    property real dragValue: 0
    readonly property real shownValue: dragging ? dragValue : value
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (shownValue - from) / (to - from))) : 0

    function snap(v) {
        const s = Math.max(1e-6, root.step)
        const n = Math.round((v - root.from) / s) * s + root.from
        return Math.max(root.from, Math.min(root.to, Number(n.toFixed(6))))
    }

    readonly property string valueText: (!isNaN(specialValue) && Math.abs(shownValue - specialValue) < 1e-6 && specialText !== "")
        ? specialText : shownValue.toFixed(decimals) + suffix

    Item {
        id: header
        width: parent.width
        height: 30

        MaterialIcon {
            id: glyph
            visible: root.icon !== ""
            x: 2
            size: 22
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            weight: Theme.settingsIconWeight
            color: Theme.pInk
        }

        Text {
            anchors.left: root.icon !== "" ? glyph.right : parent.left
            anchors.leftMargin: root.icon !== "" ? 10 : 2
            anchors.right: badge.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.label
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        // the value, in a leaning badge
        SekaiKey {
            id: badge

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            capW: valueLabel.implicitWidth + 40
            capH: 28
            skew: 0.3 * Theme.settingsLean
            radius: 10
            borderBase: 2.5
            borderLit: 2.5
            ringExtra: 0
            shadowBaseX: 2
            shadowBaseY: 2
            flatShadow: Theme.quickFlat
            lit: root.dragging

            Text {
                id: valueLabel
                anchors.centerIn: parent
                text: root.valueText
                color: root.dragging ? Theme.colBorder : Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    Item {
        id: slot
        x: 0
        y: 36
        width: parent.width
        height: 36

        // the lane
        Slant {
            id: track
            x: 14
            y: 4
            width: parent.width - 28
            height: 18
            skew: 0.55
            radius: 9
            color: Theme.pSurfaceDivider
            borderColor: Theme.pLine
            borderWidth: 3

        }

        // the fill, up to the knob
        Slant {
            x: track.x + 3 + 1
            y: track.y + 3
            height: track.height - 6
            width: Math.max(height * 0.55 + 8, (track.width - 8) * root.ratio)
            skew: 0.55
            radius: 6
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }

            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: 150 }
            }
        }

        // beat ticks
        Repeater {
            model: 11

            delegate: Rectangle {
                required property int index

                readonly property real at: index / 10

                x: track.x + 4 + at * (track.width - 8) - width / 2
                y: track.y + track.height + 3
                width: index % 5 === 0 ? 3 : 2
                height: index % 5 === 0 ? 7 : 4
                radius: 1
                color: at <= root.ratio + 0.001 ? Theme.pInk : Theme.pSurfaceDivider
                antialiasing: true
            }
        }

        // the knob: a diamond, like a note
        Item {
            id: knob

            readonly property real size: 28
            x: track.x + 4 + root.ratio * (track.width - 8) - size / 2
            y: track.y + track.height / 2 - size / 2
            width: size
            height: size
            scale: area.pressed ? 1.16 : (area.containsMouse ? 1.07 : 1)

            Behavior on scale {
                NumberAnimation { duration: 90 }
            }

            Behavior on x {
                enabled: !root.dragging
                NumberAnimation { duration: 150 }
            }

            Rectangle {
                x: 6.5 + (Theme.quickFlat ? 0 : 2)
                y: 6.5 + 2
                width: 15
                height: 15
                radius: 4
                rotation: 45
                scale: 1.35
                color: Theme.pLineShadow
                antialiasing: true
            }

            Rectangle {
                x: 6.5
                y: 6.5
                width: 15
                height: 15
                radius: 4
                rotation: 45
                scale: 1.35
                color: area.pressed ? Theme.accentMint : Theme.pSurface
                border.width: 2.5
                border.color: Theme.pLine
                antialiasing: true
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Usually inside a Flickable (a page): keep the drag.
            preventStealing: true

            function setFromX(mx) {
                const p = Math.max(0, Math.min(1, (mx - track.x - 4) / (track.width - 8)))
                const v = root.snap(root.from + p * (root.to - root.from))
                root.dragValue = v
                root.moved(v)
                PanelActivity.touch()
            }

            onPressed: mouse => {
                root.dragValue = root.value
                root.dragging = true
                setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x)
            }
            onReleased: root.dragging = false
            onCanceled: root.dragging = false
        }
    }
}
