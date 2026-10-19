import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A small slanted label tab with a diamond, the way the game's menus name
// their sections ("FORECAST", "POWER MODE"). The popups use it to give every
// block of a card a heading, in the same plate shape.
//
//   SectionTab { text: "forecast" }
Item {
    id: root

    property string text: ""
    property color tabColor: Theme.chipFill
    property color inkColor: Theme.chipInk
    property color gemColor: Theme.dark ? Theme.accentMint : Theme.colBorder

    implicitWidth: Math.ceil(label.implicitWidth + 40 + tab.lean)
    implicitHeight: 24

    Slant {
        id: tab
        anchors.fill: parent
        skew: 0.22
        radius: 8
        color: root.tabColor
        borderColor: Theme.line
        borderWidth: 2
    }

    DiamondDot {
        x: tab.lean / 2 + 10
        y: (root.height - height) / 2
        size: 7
        lit: true
        litColor: root.gemColor
        lineColor: root.tabColor
    }

    Text {
        id: label
        x: tab.lean / 2 + 26
        anchors.verticalCenter: parent.verticalCenter
        text: root.text.toUpperCase()
        color: root.inkColor
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
        font.letterSpacing: 1.2
    }
}
