import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The sort control in the wallpaper board's header: a pill with a sort
// icon, the current order's short name ("Newest", "A–Z", ...) and a
// chevron that flips while the menu (GallerySortCard) is open. It only
// says "clicked"; the gallery owns the menu.
Item {
    id: root

    property string label: ""
    property bool active: false

    signal clicked()

    width: 152
    height: 40

    readonly property bool hot: area.containsMouse
    readonly property real press: area.pressed ? 2 : 0

    // hard shadow
    Rectangle {
        x: Theme.shadowOffset - 1 - root.press
        y: Theme.shadowOffset - 1 - root.press
        width: root.width
        height: root.height
        radius: height / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        x: root.press
        y: root.press
        width: root.width
        height: root.height
        radius: height / 2
        color: root.hot && !root.active ? Theme.colHoverTint : "#ffffff"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 100 } }

        // "open" fill
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: height / 2
            visible: root.active
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentCyan }
                GradientStop { position: 1.0; color: Theme.accentMint }
            }
        }

        MaterialIcon {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            name: "sort"
            size: 22
            weight: 550
            color: Theme.colBorder
        }

        Text {
            x: 44
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 44 - 36
            elide: Text.ElideRight
            text: root.label
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyleBold
            font.weight: Font.ExtraBold
            font.pixelSize: 14
        }

        MaterialIcon {
            x: parent.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: 22
            weight: 600
            color: Theme.colBorder
            rotation: root.active ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
