import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A pill button for the Palette tool, in the bar's pill language: outline, flat
// fill, a hard shadow straight down that the face sinks into when pressed.
//
//   PaletteButton { icon: "casino"; label: "Shuffle"; onClicked: ... }
//   PaletteButton { primary: true; label: "Apply to theme" }   // accent fill
//   PaletteButton { lit: true }                                // switched on (Save, once saved)
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool primary: false
    property bool lit: false

    signal clicked()

    readonly property real lift: 3
    readonly property bool hovered: mouse.containsMouse && root.enabled

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34 + root.lift
    opacity: root.enabled ? 1 : 0.45

    Rectangle {
        y: root.lift
        width: root.width
        height: 34
        radius: 12
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: face
        y: mouse.pressed && root.enabled ? root.lift : 0
        width: root.width
        height: 34
        radius: 12
        antialiasing: true
        border.width: 2
        border.color: Theme.line
        color: root.primary ? Theme.accentCyan
            : (root.lit ? Theme.accentMint : (root.hovered ? Theme.surfaceTint : Theme.surface))

        Behavior on y { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: 18
                color: (root.primary || root.lit) ? Theme.colBorder : Theme.ink
            }

            Text {
                visible: root.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: (root.primary || root.lit) ? Theme.colBorder : Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
