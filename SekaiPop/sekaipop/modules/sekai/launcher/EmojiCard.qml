import QtQuick
import "Emoji.js" as Emoji
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// The emoji picker, made for the phone like the Calc, Clip and Web cards: no paper
// frame, just plates laid straight onto the phone's face. A row of round category
// keys on top (Recent first, once you have picked something), the grid in a plate
// under it, and a sheet at the bottom with the big emoji, its name and two keys.
// Typing after "emoji " (or ":") searches every category by name and keywords --
// ":fire", "emoji red heart".
//
//   click / Enter              copies it and closes
//   Shift+click / Shift+Enter  copies it, closes, and types it into the window you
//                              were in (needs `wtype`); the keyboard key does the same
//   arrows                     move around the grid
//
// Pure UI; ExtrasSource.qml does the copying and remembers the recents. The card is
// handed the page's size (PhoneCard.qml) and laid out for it, never shrunk.
PhoneCard {
    id: root

    property string arg: ""
    property var recent: []           // characters, newest first

    signal picked(string emoji, bool typeIt)

    readonly property bool searching: arg.trim() !== ""
    readonly property color darkInk: Theme.colBorder

    // -1 = Recent, 0.. = Emoji.groups
    property int tab: recent.length > 0 ? -1 : 0
    property int current: 0

    readonly property var items: {
        if (root.searching)
            return Emoji.search(root.arg, 300)
        if (root.tab === -1)
            return root.recent.map(ch => Emoji.find(ch))
        return Emoji.inGroup(root.tab)
    }

    onItemsChanged: current = 0
    onRecentChanged: if (tab === -1 && recent.length === 0) tab = 0

    readonly property var currentItem: (current >= 0 && current < items.length) ? items[current] : null

    // ===== the room =====
    readonly property real headH: 44
    readonly property real tabsY: headH + 12
    readonly property real tabsH: 52
    readonly property real trayY: tabsY + tabsH + 10
    readonly property real sheetH: 96
    readonly property real trayH: Math.max(150, pageH - trayY - 10 - sheetH)
    readonly property real sheetY: trayY + trayH + 10

    // The grid fills the tray's face in whole cells, so it has no half cell on the
    // right.
    readonly property int cols: 8
    readonly property real cell: Math.floor((pageW - 4 - 28) / cols)

    function nav(dx, dy) {
        if (items.length === 0)
            return
        current = Math.max(0, Math.min(items.length - 1, current + dx + dy * cols))
        grid.positionViewAtIndex(current, GridView.Contain)
    }

    function activate(typeIt) {
        if (currentItem)
            picked(currentItem[0], typeIt === true)
    }

    // ===== head: what this is, and how many =====
    Item {
        id: head

        width: root.pageW
        height: root.headH

        MaterialIcon {
            id: headIcon
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            name: "emoji_emotions"
            size: 30
            weight: 600
        }

        Text {
            anchors.left: headIcon.right
            anchors.leftMargin: 12
            anchors.right: countChip.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.searching ? "Matching \u201c" + root.arg.trim() + "\u201d"
                : (root.tab === -1 ? "Recent" : Emoji.groups[root.tab].name)
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
        }

        PhonePlate {
            id: countChip

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(54, countText.implicitWidth + 36)
            height: 38
            radius: (height - shadow) / 2
            borderW: 2.5
            shadow: 3
            fill: Theme.accentCyan

            Text {
                id: countText
                anchors.centerIn: parent
                text: root.items.length
                color: root.darkInk
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
            }
        }
    }

    // ===== category keys =====
    Row {
        id: tabs

        y: root.tabsY
        spacing: 5
        opacity: root.searching ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Repeater {
            model: {
                const t = []
                if (root.recent.length > 0)
                    t.push({ id: -1, icon: "history", name: "Recent" })
                for (let i = 0; i < Emoji.groups.length; i++)
                    t.push({ id: i, icon: Emoji.groups[i].icon, name: Emoji.groups[i].name })
                return t
            }
            delegate: Item {
                id: tabItem

                required property var modelData
                required property int index

                readonly property int count: root.recent.length > 0 ? Emoji.groups.length + 1 : Emoji.groups.length
                readonly property bool on: !root.searching && root.tab === modelData.id

                // as wide as the page lets the keys be, never wider than tall
                width: Math.min(root.tabsH, Math.floor((root.pageW - 4 - (count - 1) * 5) / count))
                height: root.tabsH

                PhonePlate {
                    anchors.fill: parent
                    radius: (height - shadow) / 2
                    borderW: tabItem.on ? 5 : 3
                    shadow: 3
                    fill: tabItem.on ? Theme.accentCyan : (tabArea.containsMouse ? Theme.pSurfaceHover : Theme.pSurface)
                    pressed: tabArea.pressed

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: tabItem.modelData.icon
                        size: 26
                        weight: 600
                        color: tabItem.on ? root.darkInk : Theme.pInkSub
                    }
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.tab = tabItem.modelData.id
                        root.current = 0
                    }
                }
            }
        }
    }

    // ===== the grid =====
    PhonePlate {
        id: tray

        y: root.trayY
        width: root.pageW
        height: root.trayH
        radius: 32

        Item {
            id: well

            x: 14
            y: 14
            width: tray.faceW - 28
            height: tray.faceH - 28
            clip: true

            WheelScroll { scroller: grid }
            GridView {
                id: grid

                anchors.fill: parent
                cellWidth: root.cell
                cellHeight: root.cell
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.items
                currentIndex: root.current
                visible: root.items.length > 0
                // a row built ahead, and cells handed on as they scroll out
                cacheBuffer: root.cell
                reuseItems: true

                delegate: Item {
                    id: cellItem

                    required property var modelData
                    required property int index

                    width: root.cell
                    height: root.cell
                    readonly property bool sel: index === root.current

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.cell - 6
                        height: root.cell - 6
                        radius: 18
                        color: cellItem.sel ? Theme.accentMint : (cellArea.containsMouse ? Theme.pSurfaceHover : "transparent")
                        border.width: cellItem.sel ? 4 : 0
                        border.color: Theme.pLine
                        antialiasing: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cellItem.modelData[0]
                        font.pixelSize: 32
                    }

                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // position, not enter: keyboard scrolling moves cells under a
                        // resting mouse, which must not steal the highlight
                        onPositionChanged: root.current = cellItem.index
                        onClicked: mouse => root.picked(cellItem.modelData[0], (mouse.modifiers & Qt.ShiftModifier) !== 0)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.items.length === 0
                text: root.searching ? "No emoji match \u201c" + root.arg.trim() + "\u201d."
                    : "Nothing here yet.\nPick an emoji and it will show up here."
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 21
                font.weight: Font.Bold
                lineHeight: 1.25
            }
        }
    }

    // a thin scroll cue for a long grid, out in the phone's margin on the right
    // (the same one the Clip card has)
    Rectangle {
        visible: grid.visible && grid.contentHeight > grid.height
        x: root.pageW + 11
        y: tray.y + well.y + (grid.height - height) * (grid.contentY / Math.max(1, grid.contentHeight - grid.height))
        width: 6
        height: Math.max(30, grid.height * grid.height / Math.max(1, grid.contentHeight))
        radius: 3
        color: Theme.pSurfaceRing
        antialiasing: true
    }

    // ===== the sheet: the picked one, its name and the keys =====
    PhonePlate {
        id: sheet

        y: root.sheetY
        width: root.pageW
        height: root.sheetH
        radius: 32

        Rectangle {
            id: disc

            x: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            width: 64
            height: 64
            radius: 32
            color: Theme.pSurfaceHover

            Text {
                anchors.centerIn: parent
                text: root.currentItem ? root.currentItem[0] : ""
                font.pixelSize: 36
            }
        }

        Column {
            anchors.left: disc.right
            anchors.leftMargin: 14
            anchors.right: typeKey.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.currentItem ? root.currentItem[1] : (root.searching ? "" : "Pick one")
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 21
                font.weight: Font.ExtraBold
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: "Enter copies \u00b7 Shift types"
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }

        PhoneKey {
            id: typeKey

            anchors.right: copyKey.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            width: 64
            height: 56
            icon: "keyboard"
            iconSize: 26
            fill: ScrapbookTheme.tapePink
            ink: root.darkInk
            enabled: root.currentItem !== null
            onClicked: root.activate(true)
        }

        PhoneKey {
            id: copyKey

            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            width: 132
            height: 56
            label: "Copy"
            fontSize: 22
            fill: Theme.accentMint
            ink: root.darkInk
            enabled: root.currentItem !== null
            onClicked: root.activate(false)
        }
    }
}
