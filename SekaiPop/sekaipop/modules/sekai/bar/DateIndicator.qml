import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Pure UI (no Quickshell imports): Status_Bar.qml feeds this the date
// text ("Mon, Sep 28"). Same pill shape as Weather / Clock — dark fill,
// white ExtraBold text, presses like a physical button. Click opens
// CalendarPopup.qml.
Item {
    id: root

    property string text: ""

    // True on a standing bar (left / right edge): "Mon, Sep 28" becomes
    // "Sep" over "28" (the weekday is in the calendar popup).
    property bool vertical: false
    readonly property var parts: root.text.replace(",", "").split(" ")
    readonly property string line1: root.parts.length >= 3 ? root.parts[1] : root.text
    readonly property string line2: root.parts.length >= 3 ? root.parts[2] : ""

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
        implicitWidth: root.vertical ? pill.barVWidth : dateIcon.width + dateLabel.implicitWidth + (pill.capsule ? 26 : 34)
        implicitHeight: root.vertical
            ? vcol.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 8 + Theme.shadowOffset
            : Theme.pillHeight + Theme.shadowOffset

        Column {
            id: vcol
            visible: root.vertical
            anchors.centerIn: parent

            Repeater {
                model: root.line2 !== "" ? [root.line1, root.line2] : [root.line1]
                Text {
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeInfo
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }

        MaterialIcon {
            id: dateIcon
            visible: !root.vertical
            name: "calendar_month"
            size: 22
            color: Theme.chipInk
            x: 10
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: dateLabel
            visible: !root.vertical
            anchors.left: dateIcon.right
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
    // move with the pressed cap — same as the clock button.
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
