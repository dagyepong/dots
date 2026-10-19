import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Pure UI, same shape as the Weather/Clock pills. Only worth showing
// when there's more than one layout configured — on a one-layout
// system this would just permanently say "EN" and take up space for
// no reason, so Bar.qml only reports a nonempty layoutCode when there's
// something to switch between. Click cycles to the next layout.
Item {
    id: root

    property string layoutCode: ""

    signal clicked()

    visible: layoutCode !== ""
    implicitWidth: layoutCode !== "" ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        fillColor: Theme.chipFill
        pressed: area.pressed
        implicitWidth: label.implicitWidth + (pill.capsule ? 20 : 28)

        Text {
            id: label
            anchors.centerIn: parent
            text: root.layoutCode
            color: Theme.chipInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
