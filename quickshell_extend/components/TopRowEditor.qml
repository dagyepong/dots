// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T O P   R O W   E D I T O R                                            │
// │   the control centre's top row, arranged by dragging                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"

// The row in miniature, its two sides, and a tray of the buttons on neither.
// A button is dragged from the tray onto a side, along it, across to the
// other, or back into the tray to take it off (`ControlsService.placeTop`).
// Used on the settings page and while the control centre is arranged, so the
// two cannot differ. Nothing moves until the drop; a bar marks where it lands.
Item {
    id: root

    // The id being dragged, where it came from, and where it would land.
    property string held: ""
    property string overSide: ""
    property int overIndex: -1
    property point pointer: Qt.point(0, 0)
    property string pointed: ""

    readonly property int piece: 32
    readonly property int pad: 10
    // On the row, as large as there is room for: every button fits, with a
    // gap down the middle.
    readonly property int placed: ControlsService.topSides.left.length
        + ControlsService.topSides.right.length
    readonly property int rowPiece: root.placed === 0 ? root.piece : Math.min(root.piece,
        Math.floor((root.width - 2 * root.pad - 24 - 4 * (root.placed - 1)) / root.placed))

    implicitHeight: column.implicitHeight

    function entryOf(id: string): var {
        return ControlsService.topEntry(id)
    }

    // The side under a point of this item's, the index a drop there takes,
    // and the tray; nothing, off both.
    function aim(point: point): void {
        const onStage = stage.contains(stage.mapFromItem(root, point.x, point.y))
        if (onStage) {
            const side = point.x < root.width / 2 ? "left" : "right"
            const row = side === "left" ? leftRow : rightRow
            let index = 0
            for (let k = 0; k < row.children.length; k++) {
                const child = row.children[k]
                if (!child.pieceId || child.pieceId === root.held)
                    continue
                const centre = child.mapToItem(root, child.width / 2, 0).x
                if (centre < point.x)
                    index++
            }
            root.overSide = side
            root.overIndex = index
            return
        }
        root.overSide = tray.contains(tray.mapFromItem(root, point.x, point.y)) ? "tray" : ""
        root.overIndex = -1
    }

    function drop(): void {
        if (root.overSide === "left" || root.overSide === "right")
            ControlsService.placeTop(root.held, root.overSide, root.overIndex)
        else if (root.overSide === "tray")
            ControlsService.placeTop(root.held, "", -1)
        root.held = ""
        root.overSide = ""
        root.overIndex = -1
    }

    // Where the marker stands for the current aim, in the stage's frame.
    readonly property real markX: {
        if (root.overSide !== "left" && root.overSide !== "right")
            return -1
        const row = root.overSide === "left" ? leftRow : rightRow
        const kids = []
        for (let k = 0; k < row.children.length; k++) {
            const child = row.children[k]
            if (child.pieceId && child.pieceId !== root.held)
                kids.push(child)
        }
        if (kids.length === 0)
            return root.overSide === "left" ? root.pad - 3 : stage.width - root.pad + 1
        if (root.overIndex >= kids.length) {
            const last = kids[kids.length - 1]
            return last.mapToItem(stage, last.width, 0).x + 1
        }
        return kids[root.overIndex].mapToItem(stage, 0, 0).x - 3
    }

    component Piece: Rectangle {
        id: tile

        property string pieceId: ""
        property int side: root.piece
        readonly property var entry: root.entryOf(tile.pieceId)

        width: tile.side
        height: tile.side
        radius: Theme.radiusSmall
        color: tileMouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1
        opacity: root.held === tile.pieceId ? 0.3 : 1

        Text {
            anchors.centerIn: parent
            text: tile.entry ? tile.entry.icon : ""
            font.family: Theme.fontMono
            font.pixelSize: 14
            color: Theme.text
        }

        MouseArea {
            id: tileMouse

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: root.held !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onContainsMouseChanged: root.pointed = tileMouse.containsMouse ? tile.pieceId
                : (root.pointed === tile.pieceId ? "" : root.pointed)
            onPressed: mouse => {
                root.held = tile.pieceId
                root.pointer = tileMouse.mapToItem(root, mouse.x, mouse.y)
                root.aim(root.pointer)
            }
            onPositionChanged: mouse => {
                if (root.held === "")
                    return
                root.pointer = tileMouse.mapToItem(root, mouse.x, mouse.y)
                root.aim(root.pointer)
            }
            onReleased: root.drop()
            onCanceled: {
                root.held = ""
                root.overSide = ""
            }
        }
    }

    Column {
        id: column

        width: root.width
        spacing: 10

        // The row, black as the island is, split down the middle.
        Rectangle {
            id: stage

            width: parent.width
            height: root.piece + 2 * root.pad
            radius: Theme.radiusLarge
            color: Theme.island
            border.color: root.overSide === "left" || root.overSide === "right"
                ? Theme.accent : Theme.islandBorder
            border.width: 1

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: parent.height - 2 * root.pad
                color: Theme.hairline
            }

            Row {
                id: leftRow

                x: root.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: ControlsService.topSides.left
                    Piece { required property string modelData; pieceId: modelData; side: root.rowPiece }
                }
            }

            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.rightMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: ControlsService.topSides.right
                    Piece { required property string modelData; pieceId: modelData; side: root.rowPiece }
                }
            }

            Rectangle {
                visible: root.held !== "" && root.markX >= 0
                x: root.markX
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: root.rowPiece
                radius: 1
                color: Theme.accent
            }
        }

        // What is under the pointer, else how it works.
        Text {
            width: parent.width
            text: {
                const shown = root.entryOf(root.held !== "" ? root.held : root.pointed)
                return shown ? Tr.t(shown.label)
                    : Tr.t("Drag a button onto either side; drag it back here to take it off.")
            }
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        Rectangle {
            id: tray

            width: parent.width
            height: Math.max(spare.implicitHeight, root.piece) + 2 * root.pad
            radius: Theme.radiusMedium
            color: "transparent"
            border.color: root.overSide === "tray" ? Theme.accent : Theme.hairline
            border.width: 1

            Flow {
                id: spare

                x: root.pad
                y: root.pad
                width: parent.width - 2 * root.pad
                spacing: 4

                Repeater {
                    model: ControlsService.topSpare
                    Piece { required property var modelData; pieceId: modelData.id }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: ControlsService.topSpare.length === 0
                text: Tr.t("Every button is on the row")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }
    }

    // The one being dragged, under the pointer.
    Rectangle {
        visible: root.held !== ""
        x: root.pointer.x - width / 2
        y: root.pointer.y - height / 2
        z: 10
        width: root.piece
        height: root.piece
        radius: Theme.radiusSmall
        color: Theme.islandSurfaceHover
        border.color: Theme.accent
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.held !== "" && root.entryOf(root.held) ? root.entryOf(root.held).icon : ""
            font.family: Theme.fontMono
            font.pixelSize: 14
            color: Theme.text
        }
    }
}
