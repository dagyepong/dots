import QtQuick
import qs.modules.common

// The huge, faint logo behind the page on the first and the last slide of the
// reference video: the same lettering as the logo, far bigger than the screen,
// drawn as a hollow outline in a shade just off the page colour, and cut off by
// the edges. It is made of plain text, drawn once, and kept as one texture
// (layer) so fading it in and out costs next to nothing.
Item {
    id: root

    property color page: "#ecfdf0"
    property color rim: Qt.tint(root.page, Qt.rgba(0.1, 0.35, 0.25, 0.075))
    property color inside: Qt.tint(root.page, Qt.rgba(1, 1, 1, 0.1))
    // 0..1 for how much of it shows (the page fades it with the slides).
    property real shown: 1

    // The lettering is sized by the page's width, but never taller than the screen.
    readonly property real fontPx: Math.min(root.width * 0.37, root.height * 0.95)
    readonly property real rimPx: root.fontPx * 0.05
    readonly property var axes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })

    opacity: root.shown
    visible: root.shown > 0.001
    clip: true

    Item {
        id: art

        anchors.centerIn: parent
        width: root.width
        height: root.height
        layer.enabled: root.visible
        layer.smooth: true

        component Lines: Item {
            id: lines

            property color ink: "#000"
            property real dx: 0
            property real dy: 0

            Text {
                x: lines.dx
                y: lines.dy
                text: "Sekai"
                color: lines.ink
                font.family: Theme.fontFamily
                font.pixelSize: root.fontPx
                font.weight: Font.Black
                font.variableAxes: root.axes
            }

            Text {
                x: lines.dx + root.fontPx * 0.95
                y: lines.dy + root.fontPx * 0.78
                text: "Pop"
                color: lines.ink
                font.family: Theme.fontFamily
                font.pixelSize: root.fontPx
                font.weight: Font.Black
                font.variableAxes: root.axes
            }
        }

        Item {
            x: -root.fontPx * 0.12
            y: root.height * 0.5 - root.fontPx * 0.95

            Repeater {
                model: 16

                Lines {
                    required property int index

                    ink: root.rim
                    dx: Math.cos(index * Math.PI / 8) * root.rimPx
                    dy: Math.sin(index * Math.PI / 8) * root.rimPx
                }
            }

            Lines {
                ink: root.inside
            }
        }
    }
}
