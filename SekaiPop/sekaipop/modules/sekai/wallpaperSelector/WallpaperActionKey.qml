import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// A big key for the Wallpapers viewer: "Set as Desktop" and "Set as Lockscreen".
// A SekaiKey with an icon and a label that lights up under the mouse, presses
// into its shadow, and flashes "Applied" (`done`) for a moment after it was used.
//
// Pure UI: whoever places it turns clicked(all) into an action.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string doneLabel: "Applied"
    // Shows the check and `doneLabel` (the viewer sets it for a moment).
    property bool done: false
    property real capW: 422
    property real capH: 76

    // `all`: Shift was held (every monitor, with One wallpaper per monitor on).
    signal clicked(bool all)

    implicitWidth: capW + 8
    implicitHeight: capH + 6

    SekaiKey {
        id: key

        capW: root.capW
        capH: root.capH
        radius: 26
        lit: root.done || area.containsMouse
        hovered: area.containsMouse
        pressed: area.pressed
        ringExtra: 6

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))

        Row {
            anchors.centerIn: parent
            spacing: 14

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                name: root.done ? "check" : root.icon
                color: key.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.done ? root.doneLabel : root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: 25
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked((mouse.modifiers & Qt.ShiftModifier) !== 0)
    }
}
