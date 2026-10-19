import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The weather pill in the bar: an icon that matches the current
// conditions plus the temperature. Pure UI (no Quickshell imports):
// Status_Bar.qml feeds it the text and the icon name from
// WeatherSource.qml (via Bar.qml). Same pill shape as Date / Clock, and it
// presses like a physical button — a click opens WeatherPopup.qml.
Item {
    id: root

    property string text: "--"
    property string iconName: "cloud"

    // True on a standing bar (left / right edge): icon over temperature.
    property bool vertical: false

    signal clicked()

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        fillColor: Theme.chipFill
        pressed: area.pressed
        ringWidth: 6   // the bar's pills all share the Utility pill's ring
        implicitWidth: root.vertical ? pill.barVWidth : weatherIcon.width + label.implicitWidth + (pill.capsule ? 26 : 34)
        implicitHeight: root.vertical
            ? vcol.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 8 + Theme.shadowOffset
            : Theme.pillHeight + Theme.shadowOffset

        Column {
            id: vcol
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 1

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.iconName
                size: 24
                color: Theme.chipInk
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.text
                color: Theme.chipInk
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeInfo
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        MaterialIcon {
            id: weatherIcon
            visible: !root.vertical
            name: root.iconName
            size: 24
            color: Theme.chipInk
            x: 10
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: label
            visible: !root.vertical
            anchors.left: weatherIcon.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Theme.chipInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    // A sibling of the Pill (not inside it) so the hit area doesn't
    // move with the pressed cap — same as the date and clock buttons.
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
