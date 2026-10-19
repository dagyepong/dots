import QtQuick
import qs.modules.common

// A small key under the lyrics (the sync keys): a sticker word that grows a little when
// you point at it and gives a click. Nothing is drawn behind it.
//
//   LyricsKey { label: "earlier"; onClicked: LyricsService.nudge(100) }
Item {
    id: root

    property string label: ""
    signal clicked

    implicitWidth: word.implicitWidth
    implicitHeight: word.implicitHeight
    width: implicitWidth
    height: implicitHeight

    scale: area.pressed ? 0.94 : (area.containsMouse ? 1.1 : 1)
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }

    LyricsWord {
        id: word
        text: root.label
        pixelSize: 15
        fillColor: area.containsMouse ? Theme.accentMint : "#FFFFFF"
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }
}
