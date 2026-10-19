import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/PaletteMath.js" as PM

// One saved palette as a small five-colour strip. Click puts it on the big strip
// (nothing about the theme changes); the cross on hover removes it. The one that is
// on the big strip right now has a thick outline.
Item {
    id: root

    property var colors: []
    property bool current: false

    signal picked()
    signal removed()

    implicitWidth: 118
    implicitHeight: 36

    Rectangle {
        y: 3
        width: root.width
        height: 32
        radius: 11
        color: Theme.lineShadow
        antialiasing: true
    }

    Item {
        id: strip
        y: mouse.containsMouse ? -1 : 0
        width: root.width
        height: 32

        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        // the colours, shaped to the rounded outline. A plain `clip` only cuts
        // to a rectangle, so the colours would poke out past the round corners:
        // the two end swatches are rounded themselves and sit under the middle
        // three, which cover their square-off.
        Item {
            id: clipBox
            anchors.fill: parent

            readonly property real cell: clipBox.width / 5
            readonly property real r: 11

            Repeater {
                model: 5
                delegate: Rectangle {
                    required property int index

                    readonly property bool isEnd: index === 0 || index === 4

                    x: index === 4 ? clipBox.cell * 4 - clipBox.r : clipBox.cell * index
                    width: isEnd ? clipBox.cell + clipBox.r : clipBox.cell + 0.5
                    height: clipBox.height
                    radius: isEnd ? clipBox.r : 0
                    z: isEnd ? 0 : 1
                    color: root.colors[index] ?? "#000000"
                    antialiasing: true
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 11
            color: "transparent"
            border.width: root.current ? 3 : 2
            border.color: root.current ? Theme.accentCyan : Theme.line
            antialiasing: true
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        // remove
        Rectangle {
            id: cross
            x: parent.width - width - 3
            y: 3
            width: 18
            height: 18
            radius: 9
            color: Theme.surface
            border.width: 2
            border.color: Theme.line
            opacity: mouse.containsMouse || crossMouse.containsMouse ? 1 : 0
            antialiasing: true
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MaterialIcon { anchors.centerIn: parent; name: "close"; size: 12; color: Theme.ink }

            MouseArea {
                id: crossMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removed()
            }
        }
    }

    MouseArea {
        id: mouse
        // a fixed area (not the strip, which moves up on hover)
        x: 0
        y: -1
        width: root.width
        height: 33
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
