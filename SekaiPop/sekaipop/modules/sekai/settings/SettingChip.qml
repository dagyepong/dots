import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone
import qs.modules.sekai.quickPanel

// A small leaning keycap that is either selected or not: the Settings
// Panel's "one of these" control (Light / Dark / Darker, the bar's position,
// a theme). It is a SekaiKey at chip size, so it behaves like the tiles:
//
//   OFF  white, outlined, a short hard shadow
//   ON   the accent gradient wipes in inside a white ring, the outline and
//        shadow grow; switching slides between them
//
// It pushes into its own hard shadow on mouse-down and springs back on
// release, and when `selected` changes without a click on this chip (the
// theme cycled from the bar, say) it pulses by itself.
//
// Pure UI: whoever places it turns clicked() into an action.
Item {
    id: root

    property string label: ""
    // A Material Symbols Rounded name, or up to three colours for a theme swatch.
    property string icon: ""
    property var swatch: []
    // Or a tiny screen drawing (see ScreenGlyph.qml): which edge the bar is
    // on, and optionally which style it has.
    property string glyphEdge: ""
    property string glyphVariant: ""
    property bool selected: false
    property real minWidth: 0

    signal clicked()

    readonly property bool hovered: area.containsMouse

    // 46 in the Settings pages; the jump chips at the top of a page use a smaller one.
    property real capH: 46
    readonly property real capW: Math.max(minWidth, row.implicitWidth + 50)

    // Sized for the ON look (cap + its shadow), like the tiles.
    implicitWidth: capW + 7
    implicitHeight: capH + 4

    property bool keyPulse: false
    property bool suppressPulse: false

    onSelectedChanged: {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 600
        onTriggered: root.suppressPulse = false
    }

    SekaiKey {
        id: key

        capW: root.capW
        capH: root.capH
        skew: 0.24 * Theme.settingsLean
        radius: 17
        lit: root.selected
        hovered: root.hovered
        pressed: area.pressed || root.keyPulse
        flatShadow: Theme.quickFlat
        ringExtra: 5

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 9

            MaterialIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                name: root.icon
                weight: Theme.settingsIconWeight
                fill: Theme.iconFill
                color: key.ink
            }

            ScreenGlyph {
                visible: root.glyphEdge !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 22
                edge: root.glyphEdge !== "" ? root.glyphEdge : "top"
                variant: root.glyphVariant
                color: key.ink
            }

            Item {
                visible: root.swatch.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 18 + (root.swatch.length - 1) * 11
                height: 18

                Repeater {
                    model: root.swatch

                    delegate: Rectangle {
                        required property int index
                        required property color modelData

                        x: index * 11
                        width: 18
                        height: 18
                        radius: 9
                        color: modelData
                        border.width: 2
                        border.color: Theme.pRingWhite
                        antialiasing: true
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    // A sibling of the key, not inside it: the cap moves while pressed and a
    // MouseArea riding along would slide out from under a click on its edge.
    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.capW
        height: root.capH
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.suppressPulse = true
        onReleased: suppressGrace.restart()
        onCanceled: suppressGrace.restart()
        onClicked: root.clicked()
    }
}
