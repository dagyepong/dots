import QtQuick
import qs.modules.common

// A one-line text field on the console screen's glass pages. If the compositor
// gives the popup no keyboard, typing does nothing: the same things can be set
// from the terminal (services/EqualizerService.qml lists the ipc calls).
Item {
    id: fld

    property real u: 1
    property string placeholder: ""
    property bool secret: false
    property alias text: input.text
    signal submitted(string value)

    function focusInput() {
        input.forceActiveFocus()
    }

    height: 24 * u

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        border.color: input.activeFocus ? PadPalette.litB : Qt.rgba(1, 1, 1, 0.3)
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10 * fld.u
        anchors.rightMargin: 10 * fld.u
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: "#ffffff"
        selectByMouse: true
        selectionColor: PadPalette.litB
        selectedTextColor: PadPalette.ink
        font.family: Theme.fontFamily
        font.pixelSize: 11 * fld.u
        echoMode: fld.secret && !input.activeFocus ? TextInput.Password : TextInput.Normal
        onAccepted: fld.submitted(input.text)
        Keys.onEscapePressed: input.focus = false
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 10 * fld.u
        visible: input.text === "" && !input.activeFocus
        text: fld.placeholder
        color: "#ffffff"
        opacity: 0.45
        font.family: Theme.fontFamily
        font.pixelSize: 11 * fld.u
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: mouse => {
            input.forceActiveFocus()
            mouse.accepted = false
        }
    }
}
