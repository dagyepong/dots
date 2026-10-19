import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One pressable key of the phone's cards: the calculator's keys, and the small
// buttons of the Clip card. A PhonePlate that pushes into its shadow while it is
// held, like every other button of the phone. It reacts on press (like a real
// calculator), and with `autoRepeat` keeps firing while held (backspace).
//
// The ink is the mode's ink on a plain key and the fixed dark ink on a coloured
// one (`fill` set to an accent), the way the Quick Panel's lit tiles do it.
Item {
    id: key

    property string label: ""
    property string icon: ""
    property color fill: Theme.pSurface
    property Gradient fillGradient: null
    property color ink: Theme.pInk
    property real fontSize: 28
    property real iconSize: 30
    property real borderW: 3
    property bool autoRepeat: false
    readonly property bool hovered: area.containsMouse

    signal clicked()

    implicitWidth: 120
    implicitHeight: 64
    opacity: enabled ? 1 : 0.4

    PhonePlate {
        anchors.fill: parent
        radius: (height - shadow) / 2
        borderW: key.borderW
        fill: key.hovered && key.enabled && key.fillGradient === null ? Qt.lighter(key.fill, 1.07) : key.fill
        fillGradient: key.fillGradient
        pressed: area.pressed

        Text {
            anchors.centerIn: parent
            visible: key.icon === ""
            text: key.label
            color: key.ink
            font.family: Theme.fontFamily
            font.pixelSize: key.fontSize
            font.weight: Font.ExtraBold
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: key.icon !== ""
            name: key.icon
            size: key.iconSize
            weight: 600
            color: key.ink
        }
    }

    Timer {
        id: repeater
        interval: 400
        repeat: true
        onTriggered: {
            interval = 60
            key.clicked()
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            key.clicked()
            if (key.autoRepeat) {
                repeater.interval = 400
                repeater.restart()
            }
        }
        onReleased: repeater.stop()
        onCanceled: repeater.stop()
    }
}
