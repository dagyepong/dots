// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   M E N U   P A N E L                                          │
// │   a tray item's menu · drawn by the shell                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// A tray item's menu as a list: the item's mark and name, then its entries.
// An entry with children replaces the list with them, and the header's
// chevron steps back out. Up and Down move, Enter or Right opens, Left goes
// back; a checked box or radio carries a check in the accent.
FocusScope {
    id: root

    signal closed()

    readonly property var item: TrayService.item
    readonly property var entries: TrayService.entries
    readonly property bool nested: TrayService.stack.length > 0

    property int current: -1

    focus: true
    Component.onCompleted: root.forceActiveFocus()
    Component.onDestruction: TrayService.stack = []

    onEntriesChanged: root.current = -1

    function usable(index: int): bool {
        const entry = root.entries[index]
        return entry !== undefined && !entry.isSeparator && entry.enabled
    }

    function move(delta: int): void {
        const count = root.entries.length
        for (let step = 1; step <= count; step++) {
            const index = ((root.current < 0 ? (delta > 0 ? -1 : 0) : root.current)
                           + delta * step + count) % count
            if (root.usable(index)) {
                root.current = index
                list.positionViewAtIndex(index, ListView.Contain)
                return
            }
        }
    }

    function run(entry: var): void {
        if (!entry || entry.isSeparator || !entry.enabled)
            return
        if (entry.hasChildren) {
            TrayService.enter(entry)
            return
        }
        entry.triggered()
        root.closed()
    }

    Keys.onUpPressed: root.move(-1)
    Keys.onDownPressed: root.move(1)
    Keys.onReturnPressed: root.run(root.entries[root.current])
    Keys.onEnterPressed: root.run(root.entries[root.current])
    Keys.onRightPressed: {
        const entry = root.entries[root.current]
        if (entry && entry.hasChildren)
            TrayService.enter(entry)
    }
    Keys.onLeftPressed: {
        if (root.nested)
            TrayService.back()
    }

    // ── HEADER ──────────────────────────────────────────────────────────────

    Item {
        id: header

        width: parent.width
        height: TrayService.headerHeight

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.nested
                text: "󰅁"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeRegular
                color: back.containsMouse ? Theme.text : Theme.textMuted
            }

            TrayIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                icon: root.item ? root.item.icon : ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: header.width - 80
                elide: Text.ElideRight
                text: root.nested
                    ? TrayService.stack[TrayService.stack.length - 1]
                    : (root.item ? (root.item.tooltipTitle || root.item.title || root.item.id) : "")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }

        MouseArea {
            id: back

            anchors.fill: parent
            enabled: root.nested
            hoverEnabled: true
            cursorShape: root.nested ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: TrayService.back()
        }
    }

    Rectangle {
        id: rule

        anchors.top: header.bottom
        anchors.topMargin: TrayService.rowSpacing
        width: parent.width
        height: 1
        color: Theme.borderIn(QsWindow.window)
    }

    // ── ENTRIES ─────────────────────────────────────────────────────────────

    ListView {
        id: list

        anchors.top: rule.bottom
        anchors.topMargin: TrayService.rowSpacing
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: TrayService.rowSpacing
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool lit: row.index === root.current
            readonly property bool checkable: row.modelData.buttonType !== QsMenuButtonType.None
            readonly property bool checked: row.modelData.checkState === Qt.Checked

            width: ListView.view.width
            height: row.modelData.isSeparator ? TrayService.separatorHeight : TrayService.rowHeight

            Rectangle {
                anchors.centerIn: parent
                visible: row.modelData.isSeparator
                width: parent.width
                height: 1
                color: Theme.borderIn(QsWindow.window)
            }

            Rectangle {
                anchors.fill: parent
                visible: !row.modelData.isSeparator
                radius: Theme.radiusSmall
                color: Theme.surfaceHoverIn(QsWindow.window)
                opacity: row.lit ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                width: parent.width - 44
                visible: !row.modelData.isSeparator
                elide: Text.ElideRight
                // As sent: a mnemonic underscore and one in a network's name
                // arrive alike, and a name is worse to lose.
                text: row.modelData.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: row.modelData.enabled ? Theme.text : Theme.textMuted
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 10
                visible: row.modelData.hasChildren || (row.checkable && row.checked)
                text: row.modelData.hasChildren ? "󰅂" : "󰄬"
                font.family: Theme.fontMono
                font.pixelSize: 14
                color: row.modelData.hasChildren ? Theme.textMuted : Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.usable(row.index)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: root.current = row.index
                onClicked: root.run(row.modelData)
            }
        }
    }
}
