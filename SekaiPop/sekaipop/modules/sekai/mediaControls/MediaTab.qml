import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One player of the media card (MediaPopup.qml), as a slanted tab like the
// popups' section tabs, wearing the colour its app was given. The player on
// show has its name; the others are a slim tab with only the app's gem on it,
// so any number of players fit on one row.
//
//   MediaTab { text: "Spotify"; tone: "#8EE3EF"; active: true }
Item {
    id: root

    property string text: ""
    property color tone: Theme.accentMint
    property bool active: true
    property real maxLabel: 90

    signal clicked()

    readonly property real skew: 0.22
    readonly property real lean: root.skew * root.height

    implicitHeight: 24
    implicitWidth: root.active ? Math.ceil(label.width + 40 + root.lean) : Math.ceil(30 + root.lean)
    scale: area.pressed ? 0.94 : 1
    Behavior on scale {
        NumberAnimation { duration: 90 }
    }
    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Slant {
        anchors.fill: parent
        skew: root.skew
        radius: 8
        color: root.active ? root.tone : (area.containsMouse ? Theme.surfaceHover : Theme.surface)
        borderColor: Theme.line
        borderWidth: 2
        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    DiamondDot {
        x: root.active ? root.lean / 2 + 10 : (root.width - width) / 2
        y: (root.height - height) / 2
        size: 7
        lit: true
        litColor: root.active ? Theme.textWhite : root.tone
        lineColor: root.active ? Theme.colBorder : Theme.line
    }

    Text {
        id: label
        visible: root.active
        x: root.lean / 2 + 26
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.maxLabel)
        elide: Text.ElideRight
        text: root.text.toUpperCase()
        color: Theme.colBorder
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
        font.letterSpacing: 1.2
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.active ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
