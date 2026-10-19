import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/ShelfMath.js" as SM

// The dock's Shelf (Dock.qml): what you have put down on the Shelf key (files dropped on
// it, or text), to pick up again. For a file: click opens it, the copy button puts it on
// the clipboard as a file (paste it into a file manager), the folder button opens the
// folder it is in. For text: click copies it. The x on a row takes it off the shelf. The card stays open
// when you click outside the dock; the X in its header closes it.
//
// It is drawn as a real shelf, in the shell's sticker look: a wall behind (the halftone dots
// Project SEKAI puts behind its panels), two strips of washi tape holding it up, and a plank
// at the bottom -- navy outline, hard shadow, the accent gradient, a lit top edge, a stud at
// each end, two diamond brackets under it. What you put down stands on the plank, and what it
// looks like depends on what it is (ShelfMath.js says which, and how big):
//
//   a folder         a folder           a picture     a polaroid (the picture itself)
//   a video          a video tape       a sound       a record in its sleeve
//   an archive       a box              a text, link  a sticky note
//   any other file   a book
//
// They keep their colour and (books, folders) their height, picked from the item. Point at one
// and it slides up out of the row and tilts, its name shows above the row and its buttons (copy,
// open the folder, take it off) come up on it; click it to open (a file) or copy (a text). The
// plank springs out wider as the card pops up. The drop area and the buttons do what they did.
//
// A shelf is as wide as it is: when the next thing no longer fits, it stands on a shelf of its
// own below, and the shelves scroll vertically: one wheel notch (or touchpad swipe, or a drag)
// moves one shelf, the line above the things says which ("2 / 3") and a scroll bar shows at the
// right.
DockCard {
    id: root

    signal closeRequested()

    readonly property var items: ShelfService.items
    // The things, packed on shelves of `listW` px with `bookGap` px between them (ShelfMath.js).
    readonly property var packed: SM.pack(root.items, root.listW, root.bookGap)
    readonly property int shelfCount: Math.max(1, root.packed.length)
    readonly property real bookGap: 4
    readonly property real bookMaxH: 120    // the tallest thing (a book); the others are shorter
    readonly property real lift: 8          // how far a book slides up when you point at it
    readonly property real areaH: root.bookMaxH + root.lift
    readonly property real nameH: 22        // the line above the books: the name of the one you point at
    readonly property real listW: 360
    readonly property real vpMargin: 16     // room each side of the shelf view for the plank's spring and a leaning book

    // True for a moment after "copy all", so its button can show a tick.
    property bool copiedAll: false

    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copiedAll = false
    }

    // What the header button under the pointer does (empty = none).
    readonly property string hint: pasteHover.hovered ? "Add what is on the clipboard"
        : (copyAllHover.hovered ? "Copy everything on the shelf" : (clearHover.hovered ? "Clear the shelf" : ""))

    // The item the pointer is on (empty = none), so the line above the books can name it.
    property string hoverId: ""
    readonly property var hoverItem: root.items.find(i => i.id === root.hoverId) ?? null

    // The plank under the rows: its height, and the room it takes (a gap above it, then the plank).
    readonly property real plankH: 18
    readonly property real ledgeBlock: 8 + root.plankH
    // One shelf in the scrolling view: the books' area, the plank, and the 10 px under it that
    // hold the plank's shadow and brackets (they hang into the card's padding).
    readonly property real unitH: root.areaH + 8 + root.plankH + 10

    contentWidth: root.listW
    contentHeight: header.height + 12
        + (root.items.length === 0 ? 44 : root.nameH + 6 + root.areaH)
        + root.ledgeBlock

    // Back to the first shelf (the newest books) when the card closes or something new is put down.
    property int lastCount: 0
    onItemsChanged: {
        if (root.items.length > root.lastCount)
            shelves.currentIndex = 0
        root.lastCount = root.items.length
        if (shelves.currentIndex > root.shelfCount - 1)
            shelves.currentIndex = root.shelfCount - 1
    }
    onOpenChanged: {
        if (!root.open)
            shelves.currentIndex = 0
    }

    // True while something is being dragged over the card (Dock.qml keeps the dock shown).
    readonly property bool dropping: cardDrop.containsDrag

    // Files or text can be dropped anywhere on the open card, not only on the Shelf key.
    DropArea {
        id: cardDrop
        anchors.fill: parent
        onDropped: (drop) => {
            ShelfService.addDrop(drop)
            drop.accept(Qt.CopyAction)
        }
    }

    // The wall behind the shelf: a faint halftone, drawn once.
    DotField {
        anchors.fill: parent
        anchors.margins: 8
        corner: "tr"
        spacing: 18
        maxRadius: 2.6
        dotColor: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.ringWidth + 4
        visible: cardDrop.containsDrag
        radius: Theme.radiusOuter - 4
        color: "transparent"
        border.width: 3
        border.color: Theme.accentCyan
        z: 5
    }

    Item {
        id: header
        x: root.pad
        y: root.pad
        width: root.listW
        height: 36

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                radius: 4
                rotation: 45
                color: Theme.accentMint
                border.width: 2
                border.color: Theme.line
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Shelf"
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // The three buttons are icons only; pointing at one says what it does on the line
            // above the things (`hint`).
            DockButton {
                height: 32
                icon: "content_paste_go"
                iconSize: 18
                onClicked: ShelfService.addFromClipboard()

                HoverHandler {
                    id: pasteHover
                }
            }

            // Everything on the shelf onto the clipboard (files as files, else the texts). It
            // shows a tick for a moment.
            DockButton {
                visible: root.items.length > 0
                height: 32
                icon: root.copiedAll ? "check" : "copy_all"
                iconSize: 18
                accent: root.copiedAll
                onClicked: {
                    ShelfService.copyAll()
                    root.copiedAll = true
                    copiedTimer.restart()
                }

                HoverHandler {
                    id: copyAllHover
                }
            }

            DockButton {
                visible: root.items.length > 0
                height: 32
                icon: "delete_sweep"
                iconSize: 18
                onClicked: ShelfService.clear()

                HoverHandler {
                    id: clearHover
                }
            }

            // Closes the card, and the dock goes away again by itself if it is set to hide.
            // The card does not close when you click outside it, so this is how it closes.
            DockButton {
                height: 32
                icon: "close"
                iconSize: 18
                onClicked: root.closeRequested()
            }
        }
    }

    Text {
        visible: root.items.length === 0
        x: root.pad
        y: root.pad + header.height + 12
        width: root.listW
        wrapMode: Text.WordWrap
        text: "Drop files or text on the Shelf key, or press Paste."
        color: Theme.inkSub
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    // ===== the line above the books =====
    Item {
        visible: root.items.length > 0
        x: root.pad
        y: root.pad + header.height + 12
        width: root.listW
        height: root.nameH

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (moreTag.visible ? moreTag.width + 10 : 0)
            elide: Text.ElideMiddle
            maximumLineCount: 1
            text: root.hoverItem ? root.hoverItem.name : (root.hint !== "" ? root.hint : "Pick one to open it")
            color: (root.hoverItem || root.hint !== "") ? Theme.ink : Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            id: moreTag
            visible: root.shelfCount > 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (shelves.currentIndex + 1) + " / " + root.shelfCount
            color: Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }

    // ===== the shelves: one plank of books after another, scrolled up and down =====
    // Each shelf holds as many things as fit in a row and has its own plank. A shelf is as tall as
    // the card's book area, so one shows at a time: the wheel (or a drag) moves to the next / previous one.
    // The view is a little wider than the shelf (`vpMargin` each side) so the plank can spring
    // out and a leaning book can tilt without being cut; the scroll bar sits in that margin.
    ListView {
        id: shelves
        visible: root.items.length > 0
        x: root.pad - root.vpMargin
        y: root.pad + header.height + 12 + root.nameH + 6
        width: root.listW + 2 * root.vpMargin
        height: root.unitH
        clip: true
        interactive: root.shelfCount > 1
        boundsBehavior: Flickable.StopAtBounds
        model: root.shelfCount
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: 0
        highlightMoveDuration: 240
        cacheBuffer: root.unitH

        delegate: Item {
            id: shelf
            required property int index

            readonly property var books: root.packed[shelf.index] ?? []

            width: shelves.width
            height: root.unitH

            // the books, standing on this shelf's plank
            Item {
                id: shelfRow
                x: root.vpMargin
                y: 10
                width: root.listW
                height: root.areaH

                Repeater {
                    model: shelf.books

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index

                        // modelData is { item, kind, seed, x, w, h } from ShelfMath.pack
                        readonly property var it: row.modelData.item
                        readonly property string kind: row.modelData.kind
                        readonly property bool isFile: row.it.kind === "file"
                        readonly property int seed: row.modelData.seed
                        readonly property color tint: Theme.attributeColors[Math.floor(row.seed / 4) % Theme.attributeColors.length]
                        readonly property bool lifted: rowHover.hovered
                        // a thin tall thing has its buttons in a column; a wide one in a row along its foot
                        readonly property bool rowButtons: SM.specOf(row.kind).buttons === "row"
                        readonly property real btnS: row.rowButtons ? 18 : 22

                        // This box is fixed (the thing's height and the room it slides up into), so the
                        // pointer stays on it while it moves.
                        x: row.modelData.x
                        y: root.areaH - row.height
                        width: row.modelData.w
                        height: row.modelData.h + root.lift
                        z: row.lifted ? 2 : 0

                        onLiftedChanged: {
                            if (row.lifted)
                                root.hoverId = row.it.id
                            else if (root.hoverId === row.it.id)
                                root.hoverId = ""
                        }

                        Component.onDestruction: {
                            if (root.hoverId === row.it.id)
                                root.hoverId = ""
                        }

                        Item {
                            id: book
                            width: row.modelData.w
                            height: row.modelData.h
                            y: (row.lifted ? 0 : root.lift) + (area.pressed ? 2 : 0)
                            rotation: row.lifted ? -2.5 : SM.restTilt(row.kind, row.seed)
                            transformOrigin: Item.Bottom

                            Behavior on y {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2 }
                            }

                            Behavior on rotation {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2 }
                            }

                            // what it looks like: one drawing per kind
                            Loader {
                                anchors.fill: parent
                                sourceComponent: {
                                    switch (row.kind) {
                                    case "folder": return folderFace
                                    case "image": return photoFace
                                    case "video": return tapeFace
                                    case "audio": return vinylFace
                                    case "archive": return boxFace
                                    case "note": return noteFace
                                    }
                                    return bookFace
                                }
                            }

                            Component {
                                id: bookFace
                                ShelfBook { item: row.it; icon: SM.iconOf(row.it); tint: row.tint; lifted: row.lifted }
                            }

                            Component {
                                id: folderFace
                                ShelfFolder { item: row.it; tint: row.tint; lifted: row.lifted }
                            }

                            Component {
                                id: photoFace
                                ShelfPolaroid { item: row.it; tint: row.tint; lifted: row.lifted }
                            }

                            Component {
                                id: tapeFace
                                ShelfTape { item: row.it; tint: row.tint; lifted: row.lifted }
                            }

                            Component {
                                id: vinylFace
                                ShelfVinyl { item: row.it; tint: row.tint; lifted: row.lifted }
                            }

                            Component {
                                id: boxFace
                                ShelfBox { item: row.it; tint: row.tint; lifted: row.lifted }
                            }

                            Component {
                                id: noteFace
                                ShelfNote { item: row.it; tint: row.tint; lifted: row.lifted }
                            }

                            // Click it: open it (a file) or copy it (a text), and the card closes.
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (row.isFile)
                                        ShelfService.open(row.it)
                                    else
                                        ShelfService.copy(row.it)
                                    root.closeRequested()
                                }
                            }

                            // The buttons, after the thing's own MouseArea so they take their clicks:
                            // up a tall thing, along the foot of a wide one.
                            Grid {
                                id: btns
                                columns: row.rowButtons ? 3 : 1
                                spacing: row.rowButtons ? 3 : 4
                                x: (book.width - width) / 2
                                y: row.rowButtons ? book.height - height - 7 : 14
                                opacity: row.lifted ? 1 : 0
                                visible: opacity > 0.01

                                Behavior on opacity {
                                    NumberAnimation { duration: 110 }
                                }

                                Repeater {
                                    model: row.isFile ? ["copy", "folder", "x"] : ["copy", "x"]

                                    delegate: Rectangle {
                                        id: btn
                                        required property string modelData
                                        width: row.btnS
                                        height: row.btnS
                                        radius: row.rowButtons ? 6 : 7
                                        color: Theme.surface
                                        border.width: 2
                                        border.color: ma.containsMouse ? (btn.modelData === "x" ? "#e0575b" : Theme.accentMint) : Theme.line
                                        antialiasing: true

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            name: btn.modelData === "copy" ? "content_copy" : (btn.modelData === "folder" ? "folder_open" : "close")
                                            size: row.rowButtons ? 12 : 14
                                            weight: 700
                                        }

                                        MouseArea {
                                            id: ma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (btn.modelData === "copy")
                                                    ShelfService.copy(row.it)
                                                else if (btn.modelData === "folder")
                                                    ShelfService.revealInFolder(row.it)
                                                else
                                                    ShelfService.remove(row.it.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // True while the pointer is anywhere on the thing's box, buttons included.
                        HoverHandler {
                            id: rowHover
                        }
                    }
                }
            }

            // ===== this shelf's plank =====

            Item {
                id: ledge

                // Springs out from the middle as the card pops up (`shown` overshoots a little).
                readonly property real grow: 0.7 + 0.3 * Math.min(1.12, root.shown)
                readonly property real fullW: root.listW + 16

                width: ledge.fullW * ledge.grow
                height: root.plankH + Theme.shadowOffset
                x: root.vpMargin - 8 + (ledge.fullW - ledge.width) / 2
                y: root.areaH + 8

                Gradient {
                    id: plankFill
                    GradientStop { position: 0.0; color: Theme.accentMint }
                    GradientStop { position: 1.0; color: Theme.accentCyan }
                }

                // The brackets: diamonds, half hidden behind the plank, so what shows is a triangle.
                Repeater {
                    model: 2

                    Rectangle {
                        required property int index

                        x: index === 0 ? 26 : ledge.width - 26 - 12
                        y: root.plankH - 5
                        width: 12
                        height: 12
                        radius: 3
                        rotation: 45
                        color: Theme.surface
                        border.width: 2
                        border.color: Theme.line
                        antialiasing: true
                    }
                }

                Rectangle {
                    y: Theme.shadowOffset
                    width: ledge.width
                    height: root.plankH
                    radius: 7
                    color: Theme.lineShadow
                    antialiasing: true
                }

                Rectangle {
                    id: board
                    width: ledge.width
                    height: root.plankH
                    radius: 7
                    border.width: Theme.borderWidth
                    border.color: Theme.line
                    gradient: plankFill
                    antialiasing: true

                    // The lit top edge.
                    Rectangle {
                        x: 22
                        y: 4
                        width: Math.max(0, board.width - 44)
                        height: 2
                        radius: 1
                        color: "white"
                        opacity: 0.45
                    }

                    // A stud at each end (the diamond the shell's notes use).
                    Repeater {
                        model: 2

                        Rectangle {
                            required property int index

                            x: (index === 0 ? 11 : board.width - 11) - width / 2
                            y: (board.height - height) / 2
                            width: 6
                            height: 6
                            radius: 1.5
                            rotation: 45
                            color: Theme.surface
                            border.width: 1.5
                            border.color: Theme.line
                            antialiasing: true
                        }
                    }
                }
            }
        }

        SekaiScrollBar {
            inset: 0
        }
    }

    // One wheel notch (or one touchpad swipe) moves one shelf.
    Item {
        id: wheelHost
        anchors.fill: shelves
        z: 50
        visible: shelves.visible && root.shelfCount > 1

        property real acc: 0
        property bool cooling: false

        Timer {
            id: coolDown
            interval: 220
            onTriggered: wheelHost.cooling = false
        }

        Timer {
            id: settle
            interval: 300
            onTriggered: wheelHost.acc = 0
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const d = Theme.wheelPx(event, false)
                if (d === 0 || wheelHost.cooling)
                    return
                wheelHost.acc += d
                settle.restart()
                if (wheelHost.acc >= 60) {
                    shelves.currentIndex = Math.max(0, shelves.currentIndex - 1)
                } else if (wheelHost.acc <= -60) {
                    shelves.currentIndex = Math.min(root.shelfCount - 1, shelves.currentIndex + 1)
                } else {
                    return
                }
                wheelHost.acc = 0
                wheelHost.cooling = true
                coolDown.restart()
            }
        }
    }

    // ===== tape holding the wall up =====
    WashiTape {
        x: 30
        y: -root.ringWidth - 10
        width: 84
        height: 22
        rotation: -5
        color: ScrapbookTheme.tapeMint
    }

    WashiTape {
        x: root.listW + 2 * root.pad - 30 - 84
        y: -root.ringWidth - 10
        width: 84
        height: 22
        rotation: 4
        color: ScrapbookTheme.tapePink
    }
}
