import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// One row in the App Launcher's results card: icon, name, and (if the
// .desktop entry has one) its short description. `app` is normally a
// desktop entry; it can also be one of the extras' plain entries
// (`isAction: true` -- a system action like "Lock screen" or a shell command,
// see ExtrasSource.qml), which draw a Material glyph and their own title /
// subtitle, and turn coral with "Press Enter again to confirm" while
// `confirming` (the destructive ones) — the same hover-pill
// language as TrayMenuRow.qml, just bigger. `selected` is driven by
// Overview.qml's arrow-key navigation, independent of mouse hover,
// so keyboard-only use always shows exactly one row picked out even if
// the mouse is sitting somewhere else entirely.
Item {
    id: row

    property var app: null
    property bool selected: false
    property bool confirming: false

    readonly property bool isAction: app !== null && app.isAction === true

    signal activated()

    readonly property int iconSize: 34
    readonly property int leftPad: 12
    readonly property int rightPad: 16

    implicitHeight: 58

    // Resting fill is a light grey (not transparent) so the rows read
    // as separate stadiums inside the white card, matching "Frame 6
    // Transition When Searching" in the design reference. Hover
    // lightens it further; keyboard selection gets its own cyan wash
    // so it's still obvious with the mouse sitting somewhere else.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: row.confirming ? (Theme.dark ? Qt.tint(Theme.surface, Qt.rgba(0.91, 0.53, 0.44, 0.3)) : "#fde3da")
            : row.selected ? Qt.rgba(0.016, 0.996, 0.933, 0.35)
            : (area.containsMouse ? Theme.paperHover : Theme.paper)
        // Keyboard selection also gets the bar's navy outline, so it
        // reads as "stamped" even against the warm paper.
        border.width: (row.selected || row.confirming) ? 2.5 : 0
        border.color: row.confirming ? ScrapbookTheme.tapeCoral : Theme.line
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    // Soft rounded-square backing behind the icon, so a missing or
    // slow-to-load icon still reads as a tile rather than a blank gap
    // — the grey placeholder squares in the design reference.
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: row.leftPad
        anchors.verticalCenter: parent.verticalCenter
        width: row.iconSize
        height: row.iconSize
        radius: 9
        color: Theme.paperEdge
    }

    // An app with no icon (none named, none in the theme, or one that fails to load) gets
    // the coloured first-letter key instead of an empty square.
    readonly property string iconPath: (row.app && !row.isAction) ? IconCursorService.path(row.app.icon, true) : ""
    readonly property bool noIcon: !row.isAction && row.app !== null && (row.iconPath === "" || rowIcon.status === Image.Error)

    IconImage {
        id: rowIcon

        anchors.left: parent.left
        anchors.leftMargin: row.leftPad
        anchors.verticalCenter: parent.verticalCenter
        width: row.iconSize
        height: row.iconSize
        asynchronous: true
        visible: !row.isAction && !row.noIcon
        source: row.iconPath
    }

    Loader {
        active: row.noIcon
        anchors.left: parent.left
        anchors.leftMargin: row.leftPad
        anchors.verticalCenter: parent.verticalCenter
        width: row.iconSize
        height: row.iconSize
        sourceComponent: AppPlaceholder {
            size: row.iconSize - 2
            name: row.app ? row.app.name : ""
        }
    }

    // an action's icon is a Material glyph on the same rounded tile
    MaterialIcon {
        anchors.left: parent.left
        anchors.leftMargin: row.leftPad + (row.iconSize - size) / 2
        anchors.verticalCenter: parent.verticalCenter
        visible: row.isAction
        name: row.isAction ? row.app.glyph : ""
        size: 24
        weight: 600
        color: row.confirming ? ScrapbookTheme.tapeCoral : Theme.ink
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: row.leftPad + row.iconSize + 12
        anchors.right: parent.right
        anchors.rightMargin: row.rightPad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.isAction ? row.app.title : (row.app ? row.app.name : "")
            elide: Text.ElideRight
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTitle + 2
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: row.isAction ? (row.confirming ? "Press Enter again to confirm" : row.app.sub)
                : (row.app ? row.app.genericName : "")
            visible: text !== ""
            elide: Text.ElideRight
            color: Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSub + 2
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
