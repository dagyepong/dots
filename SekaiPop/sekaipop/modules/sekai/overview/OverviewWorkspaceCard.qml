import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One workspace's card in the Overview: one *frame* of the film strip
// Overview.qml draws behind it — a "Workspace N" line of amber edge print
// over a to-scale mock of the screen. It is only the frame: the window
// thumbnails are not children of it. They live in Overview.qml's shared
// `windowSpace` layer, drawn above every card, so a tile can be dragged
// from one card to another without being clipped by the card it started
// on. What this card does own:
//
//   - the drop target (`DropArea`): while a tile is dragged over it,
//     `dragEntered` / `dragExited` tell Overview.qml which workspace
//     it would land on
//   - click to switch to this workspace (`clicked`) — a tile sitting
//     above it takes its own clicks first
//
// Overview.qml sizes and positions each card (it also needs those
// numbers to place the tiles), so nothing here computes a layout.
// The sprocket holes on either side are FilmStrip.qml's, lined up with
// the same numbers.
Item {
    id: root

    required property int workspaceId
    property real areaWidth: 300
    property real areaHeight: 170
    property real cellPad: 10
    property real headerHeight: 28
    property int windowCount: 0

    // True while a tile is being dragged over this card.
    readonly property bool dropHover: dropArea.containsDrag

    signal clicked()
    signal dragEntered()
    signal dragExited()

    // The frame: a slightly lighter box on the film, with a dark gap line round it.
    Rectangle {
        id: card
        width: root.width
        height: root.height
        radius: 4
        color: ScrapbookTheme.filmFrame
        border.width: 2
        border.color: ScrapbookTheme.filmEdge
    }

    // ===== amber edge print, like the numbers printed on real film =====
    Text {
        x: root.cellPad
        y: 5
        height: root.headerHeight - 6
        verticalAlignment: Text.AlignVCenter
        text: "WORKSPACE " + root.workspaceId
        color: ScrapbookTheme.filmPrint
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
    }

    // frame counter on the right: "▸ 3A"
    Text {
        x: root.width - width - root.cellPad
        y: 5
        height: root.headerHeight - 6
        verticalAlignment: Text.AlignVCenter
        text: "\u25B8 " + root.workspaceId + "A"
        color: ScrapbookTheme.filmPrint
        opacity: 0.85
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
    }

    // The picture area: the mock screen the tiles are laid out on.
    Rectangle {
        id: screenArea
        x: root.cellPad
        y: root.headerHeight
        width: root.areaWidth
        height: root.areaHeight
        radius: 3
        color: root.dropHover ? ScrapbookTheme.filmScreenHover : ScrapbookTheme.filmScreen
        border.width: 1.5
        border.color: "#55efe7d4"
        Behavior on color { ColorAnimation { duration: 100 } }

        // Big faint workspace number, behind the tiles.
        Text {
            anchors.centerIn: parent
            text: root.workspaceId
            color: "#14f5eed8"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(screenArea.height * 0.6)
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            anchors.centerIn: parent
            visible: root.windowCount === 0
            text: "Empty"
            color: ScrapbookTheme.filmPrintSoft
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // Click anywhere on the card to jump to this workspace. Declared
    // before the DropArea and, as a sibling of the shared tile layer
    // (which sits above), it only ever sees clicks a tile didn't take.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: root.dragEntered()
        onExited: root.dragExited()
    }
}
