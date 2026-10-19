import QtQuick
import qs.modules.common

// The search field in the wallpaper board's header: a white pill that's
// always there (no toggle), with the shell's outline + hard shadow and a
// cyan ring while it's focused. Only reports the typed text (`text`); the
// filtering happens in WallpaperFace.qml, which owns the list.
//
// Escape clears a non-empty field first; with nothing typed it isn't
// accepted, so it carries on up to the gallery (closes the sort card, then
// the picker). Enter / Down hand the keyboard back to the gallery
// (leave()), so Left/Right scroll the row again.
Item {
    id: root

    property alias text: input.text
    property string placeholder: "Search"
    readonly property bool focused: input.activeFocus

    signal leave()

    // true = Up / Down report stepped(-1 / 1) instead of Down handing the
    // keyboard back (leave()).
    property bool stepKeys: false
    signal stepped(int direction)

    width: 240
    height: 40

    // Put the cursor in the field (optionally starting with a typed
    // character — the gallery uses this for "just start typing").
    function begin(seed) {
        input.forceActiveFocus();
        if (seed && seed.length > 0)
            input.text = input.text + seed;
        input.cursorPosition = input.text.length;
    }

    function clear() {
        input.text = "";
    }

    // hard shadow
    Rectangle {
        x: Theme.shadowOffset - 1
        y: Theme.shadowOffset - 1
        width: root.width
        height: root.height
        radius: height / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }

        // focus ring
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.accentCyan
            visible: input.activeFocus
            antialiasing: true
        }

        MaterialIcon {
            id: glass
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 22
            weight: 550
            color: Theme.ink
        }

        Text {
            visible: input.text.length === 0
            anchors.left: glass.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: ScrapbookTheme.inkSoft
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        TextInput {
            id: input
            anchors.left: glass.right
            anchors.leftMargin: 8
            anchors.right: clearBtn.visible ? clearBtn.left : parent.right
            anchors.rightMargin: clearBtn.visible ? 6 : 16
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 15

            Keys.onEscapePressed: event => {
                if (input.text.length > 0) {
                    input.text = "";
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
            Keys.onReturnPressed: root.leave()
            Keys.onEnterPressed: root.leave()
            Keys.onDownPressed: root.stepKeys ? root.stepped(1) : root.leave()
            Keys.onUpPressed: event => {
                if (root.stepKeys)
                    root.stepped(-1)
                else
                    event.accepted = false
            }
        }

        Rectangle {
            id: clearBtn
            visible: input.text.length > 0
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            color: clearArea.containsMouse ? Theme.surfaceTint : Theme.surfaceDivider

            MaterialIcon {
                anchors.centerIn: parent
                name: "close"
                size: 15
                weight: 600
                color: Theme.ink
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    input.text = "";
                    input.forceActiveFocus();
                }
            }
        }
    }
}
