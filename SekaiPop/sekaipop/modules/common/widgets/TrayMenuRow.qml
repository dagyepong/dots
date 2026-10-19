import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.modules.common

// One row of the tray right-click menu, matching the Figma frame:
// text in Google Sans Flex, an optional icon before it, and a full-width
// light-grey pill behind the row you're hovering.
//
// A row can carry:
//   - an app-provided icon (iconSource)
//   - a check mark (checked), for checkable entries
//   - a chevron (hasChildren), for entries that open a submenu
//   - its own glyph — anything declared inside the row lands in the
//     icon slot (used for the Pin / Back arrows)
// or be a separator line.
Item {
    id: row

    property string text: ""
    property string iconSource: ""
    property bool checked: false
    property bool hasChildren: false
    property bool separator: false
    property bool dim: false          // disabled entry: greyed, not clickable

    // Real screen pixels per design pixel here (shell scale x the screen's
    // device pixel ratio). The tray glyphs are Shapes drawn through a
    // layer (for anti-aliasing); a layer is made at the item's design
    // size unless it is told otherwise, and the scale then stretches that
    // small picture -- soft above 100%. The owner sets this; 1 = old look.
    property real texel: 1

    default property alias glyph: glyphSlot.data

    signal clicked()

    // Figma: text starts ~24px into the hover pill, ~47px when an icon
    // comes first; rows with no icon don't reserve space for one.
    readonly property int leftPad: 24
    readonly property int iconSize: 18
    readonly property int iconGap: 5
    readonly property int rightPad: 16
    readonly property int chevronWidth: 14
    readonly property int maxTextWidth: 240

    readonly property bool hasIcon: iconSource !== "" || checked || glyphSlot.children.length > 0

    implicitHeight: separator ? 9 : Theme.menuRowHeight
    implicitWidth: separator ? 0 : leftPad
        + (hasIcon ? iconSize + iconGap : 0)
        + Math.min(label.implicitWidth, maxTextWidth)
        + rightPad + (hasChildren ? chevronWidth : 0)

    // Hover pill.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceHover
        visible: !row.separator && !row.dim && area.containsMouse
    }

    // Separator line.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: 2
        radius: 1
        color: Theme.surfaceDivider
        visible: row.separator
    }

    // Icon slot: custom glyph, app icon, or check mark.
    Item {
        id: glyphSlot
        x: row.leftPad
        anchors.verticalCenter: parent.verticalCenter
        width: row.iconSize
        height: row.iconSize
        visible: !row.separator
    }

    IconImage {
        x: row.leftPad
        anchors.verticalCenter: parent.verticalCenter
        width: row.iconSize
        height: row.iconSize
        source: row.iconSource
        visible: !row.separator && row.iconSource !== ""
        opacity: row.dim ? 0.5 : 1
    }

    Shape {
        x: row.leftPad
        anchors.verticalCenter: parent.verticalCenter
        width: row.iconSize
        height: row.iconSize
        visible: row.checked
        layer.enabled: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * row.texel)),
                                    Math.max(1, Math.ceil(height * row.texel)))

        ShapePath {
            strokeColor: Theme.ink
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M3 9L7.5 13.5L15 4.5" }
        }
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: row.leftPad + (row.hasIcon ? row.iconSize + row.iconGap : 0)
        anchors.right: parent.right
        anchors.rightMargin: row.rightPad + (row.hasChildren ? row.chevronWidth : 0)
        visible: !row.separator
        text: row.text
        elide: Text.ElideRight
        color: row.dim ? Theme.inkSub : Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMenu
        font.weight: Font.DemiBold
    }

    // Submenu chevron.
    Shape {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: row.rightPad - 2
        width: 8
        height: 12
        visible: row.hasChildren
        layer.enabled: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * row.texel)),
                                    Math.max(1, Math.ceil(height * row.texel)))

        ShapePath {
            strokeColor: row.dim ? Theme.inkSub : Theme.ink
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M1 1L6 6L1 11" }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: !row.separator && !row.dim
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
