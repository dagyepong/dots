import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One round button in the wallpaper board's header: a line icon in the
// shell's outline + hard-shadow style, with a small tooltip that fades in
// under it on hover (`label`). Off = white; hover = pale mint; `active` =
// the cyan-to-mint fill the Quick Panel's toggles use when they're on. A
// pink dot (`badge`) means "something's waiting" (used on Refresh).
Item {
    id: root

    property string icon: ""
    property string label: ""       // tooltip
    property bool active: false
    property bool badge: false

    signal clicked()

    width: 40
    height: 40

    readonly property bool hot: area.containsMouse
    readonly property real press: area.pressed ? 2 : 0

    // hard shadow
    Rectangle {
        x: Theme.shadowOffset - 1 - root.press
        y: Theme.shadowOffset - 1 - root.press
        width: root.width
        height: root.height
        radius: width / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: face
        x: root.press
        y: root.press
        width: root.width
        height: root.height
        radius: width / 2
        color: root.hot && !root.active ? Theme.colHoverTint : "#ffffff"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 100 } }

        // "on" fill
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: width / 2
            visible: root.active
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentCyan }
                GradientStop { position: 1.0; color: Theme.accentMint }
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            name: root.icon
            size: 24
            weight: 550
            color: Theme.colBorder
        }

        Rectangle {
            visible: root.badge
            x: parent.width - 14
            y: -3
            width: 15
            height: 15
            radius: 7.5
            color: ScrapbookTheme.accentPink
            border.width: 3
            border.color: Theme.line
            antialiasing: true
        }
    }

    // tooltip
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height + 12
        width: tipText.implicitWidth + 22
        height: 26
        radius: 8
        color: Theme.colBorder
        opacity: root.hot && root.label !== "" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.label
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyleBold
            font.weight: Font.ExtraBold
            font.pixelSize: 12
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
