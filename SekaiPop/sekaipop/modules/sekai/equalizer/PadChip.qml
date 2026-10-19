import QtQuick
import qs.modules.common

// A small pill on the console screen's glass pages (presets, setup). `lit` fills
// it with the accent gradient.
Item {
    id: chip

    property real u: 1
    property string text: ""
    property bool lit: false
    signal clicked()
    signal rightClicked()

    implicitHeight: 22 * u
    implicitWidth: label.implicitWidth + 20 * u
    width: implicitWidth
    height: implicitHeight

    Gradient {
        id: chipGrad
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: PadPalette.litA }
        GradientStop { position: 1.0; color: PadPalette.litB }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: chip.lit ? "transparent" : Qt.rgba(1, 1, 1, ca.containsMouse ? 0.16 : 0.08)
        border.width: chip.lit ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.28)
        gradient: chip.lit ? chipGrad : null
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.lit ? PadPalette.ink : "#ffffff"
        font.family: Theme.fontFamily
        font.pixelSize: 10.5 * chip.u
        font.weight: Font.Bold
    }
    MouseArea {
        id: ca
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                chip.rightClicked()
            else
                chip.clicked()
        }
    }
}
