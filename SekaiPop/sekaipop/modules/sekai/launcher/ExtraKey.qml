import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One pressable key -- the calculator's buttons, and any small pill button
// in the extras cards. It is a Pill (outline, white ring, hard shadow), so
// it pushes into its shadow on press and springs back like every other
// button in the shell. Reacts on press (like a real calculator), and with
// `autoRepeat` keeps firing while held (backspace).
Item {
    id: key

    property string label: ""
    property string icon: ""
    property color fill: "#ffffff"
    property Gradient fillGradient: null
    property color ink: Theme.colBorder
    property real fontSize: 20
    property real iconSize: 22
    property bool autoRepeat: false
    property bool hovered: area.containsMouse

    signal clicked()

    implicitWidth: 68
    implicitHeight: 46

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Math.min(14, height / 2.4)
        ringWidth: 3
        borderWidth: 2.5
        shadowDx: 0
        shadowDy: 3
        fillColor: key.hovered ? Qt.lighter(key.fill, 1.06) : key.fill
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
            font.styleName: Theme.fontStyleBold
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
