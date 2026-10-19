import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The status pill: Wi-Fi / Ethernet, Bluetooth and the speaker as icons, side
// by side in one pill, and nothing else. Pure UI: Bar.qml feeds it
// StatusIconsService's state.
//
//   [ wifi ] [ bluetooth ] [ speaker ]
//
// Each icon is drawn at full strength when it is up (connected, a device
// connected, sound on), a little dimmer when it is on but idle (Wi-Fi on with
// no network, Bluetooth on with nothing connected) and dim when it is off or
// muted. An icon with nothing behind it (no Bluetooth adapter, no audio
// output) is left out, and the pill takes no room when all of them are.
// Hover it for the details, one line per icon; a click opens the Quick Panel,
// where the switches are.
Item {
    id: root

    property bool vertical: false
    // Which edge the bar is on, so the tag opens towards the screen.
    property string barPosition: "top"

    property bool networkShown: false
    property string networkIcon: "wifi_off"
    property string networkState: "off"      // "on" | "idle" | "off"

    property bool bluetoothShown: false
    property string bluetoothIcon: "bluetooth_disabled"
    property string bluetoothState: "off"

    property bool speakerShown: false
    property string speakerIcon: "volume_off"
    property string speakerState: "off"

    // What the hover tag says (one line per icon).
    property string detailText: ""

    signal clicked()

    readonly property bool anyShown: networkShown || bluetoothShown || speakerShown
    visible: anyShown

    function strength(state) {
        return state === "on" ? 1.0 : (state === "idle" ? 0.7 : 0.4)
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: 6   // the bar's pills all share the Utility pill's ring
        fillColor: Theme.chipFill
        pressed: area.pressed

        implicitWidth: root.vertical ? pill.barVWidth
                                     : row.implicitWidth + 2 * ringWidth + 14
        implicitHeight: root.vertical ? col.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 12 + Theme.shadowOffset
                                      : Theme.pillHeight + Theme.shadowOffset

        Row {
            id: row
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 7

            MaterialIcon {
                visible: root.networkShown
                anchors.verticalCenter: parent.verticalCenter
                name: root.networkIcon
                size: 18
                fill: 1
                color: Theme.chipInk
                opacity: root.strength(root.networkState)
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
            MaterialIcon {
                visible: root.bluetoothShown
                anchors.verticalCenter: parent.verticalCenter
                name: root.bluetoothIcon
                size: 18
                fill: 1
                color: Theme.chipInk
                opacity: root.strength(root.bluetoothState)
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
            MaterialIcon {
                visible: root.speakerShown
                anchors.verticalCenter: parent.verticalCenter
                name: root.speakerIcon
                size: 18
                fill: 1
                color: Theme.chipInk
                opacity: root.strength(root.speakerState)
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }

        Column {
            id: col
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 5

            MaterialIcon {
                visible: root.networkShown
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.networkIcon
                size: 18
                fill: 1
                color: Theme.chipInk
                opacity: root.strength(root.networkState)
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
            MaterialIcon {
                visible: root.bluetoothShown
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.bluetoothIcon
                size: 18
                fill: 1
                color: Theme.chipInk
                opacity: root.strength(root.bluetoothState)
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
            MaterialIcon {
                visible: root.speakerShown
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.speakerIcon
                size: 18
                fill: 1
                color: Theme.chipInk
                opacity: root.strength(root.speakerState)
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    BarTip {
        shown: area.containsMouse
        text: root.detailText
        barPosition: root.barPosition
    }
}
