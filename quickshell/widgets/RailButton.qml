import QtQuick
import qs.theme

// A button of the side bar: icon, highlighted while its panel is open
Item {
    id: root

    property string icon: "gear"
    property int level: 3
    property color tone: Theme.foreground
    property real glyphSize: 16
    property bool active: false
    property bool badge: false
    readonly property bool hovered: mouse.containsMouse

    // y (in screen coordinates) of the button's center, to place its panel next to it
    signal activated(real cy)
    signal entered(real cy)
    signal exited()

    function cy() { return root.mapToItem(null, 0, root.height / 2).y }

    implicitWidth: 34
    implicitHeight: 34
    width: 34; height: 34

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.active ? Theme.accent : (root.hovered ? Theme.islandHover : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Glyph {
        anchors.centerIn: parent
        kind: root.icon
        level: root.level
        size: root.glyphSize
        color: root.active ? Theme.island : root.tone
    }

    Rectangle {
        visible: root.badge
        x: parent.width - 11; y: 5
        width: 7; height: 7
        radius: 3.5
        color: Theme.accent
        border.width: 1
        border.color: Theme.island
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated(root.cy())
        onEntered: root.entered(root.cy())
        onExited: root.exited()
    }
}
