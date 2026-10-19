import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/NotesMath.js" as NM

// ONE sticky note: a coloured paper in the shell's outlined-pill style, with a
// header strip and a text area. It is the delegate of the Repeater in
// StickyNotesWidget.qml, so the widget fills in the note's row (the required
// properties below are the ListModel's roles) and where the note is drawn
// (`room`, `roomW`, `roomH`, `reveal`, `mine`).
//
//   Move      press and drag the header strip (the bare part of it).
//   Resize    drag the grip in the bottom-right corner, or the right / bottom edge.
//   Edit      click the text and type; Esc leaves the text. Saved as you type.
//   Keys      (header, shown while the pointer is on the note and while nothing is
//             being moved or resized)   +  new note,  palette  colour,
//             pin  float above windows,  bin  delete (asks once if it has text).
//
// Why the controls cannot get in the way of moving and resizing:
//   - they live only in the header, which has nothing else on it but the drag area
//     under them; a press on a key goes to the key, a press anywhere else on the
//     header starts a move
//   - the resize zones are on the right / bottom edges and the corner, clear of the
//     header, and a resize does not start from a key or from the text
//   - while a move or a resize is going on the keys are hidden and switched off, and
//     the drag area keeps the pointer (preventStealing), so nothing can take it over
//
// The live position / size go straight into the service's row (setGeometry) so the
// input mask follows the note; they are saved once, when the pointer is let go.
Item {
    id: note

    // ----- the row (ListModel roles, see services/NotesService.qml) -----
    required property string nid
    required property string body
    required property string tint
    required property real nx
    required property real ny
    required property real nw
    required property real nh
    required property real nz
    required property bool pinned

    // ----- from the widget -----
    property Item room: null
    property real roomW: 0
    property real roomH: 0
    property real reveal: 1
    // This layer is the one that draws this note (pinned ones are on the Top layer,
    // see StickyNotesWidget.qml). A note that is not drawn here builds nothing.
    property bool mine: true

    // Keeps the classic (light) look in the first dark mode; see Theme.classicFor.
    readonly property bool classicPanel: true

    readonly property color paper: NM.paperOf(note.tint)
    readonly property color ink: Theme.colBorder

    property bool moving: false
    property bool resizing: false
    readonly property bool busy: note.moving || note.resizing

    // The shelf-like bounce when a note is made (see NotesService.freshId).
    property real born: 1

    x: note.nx
    y: note.ny
    width: note.nw
    height: note.nh
    z: note.nz
    visible: note.mine
    scale: Math.max(0, note.born) * Math.max(0, note.reveal)
    transformOrigin: Item.Center

    function raiseMe() {
        NotesService.raise(note.nid)
    }

    Component.onCompleted: {
        if (note.mine && NotesService.freshId === note.nid) {
            note.born = 0
            bornAnim.start()
        }
    }

    NumberAnimation {
        id: bornAnim
        target: note
        property: "born"
        to: 1
        duration: 420
        easing.type: Easing.OutBack
        easing.overshoot: 1.7
        onFinished: {
            if (NotesService.freshId === note.nid)
                NotesService.freshId = ""
        }
    }

    // A small square key, transparent until hovered.
    component NoteBtn: Rectangle {
        id: btn

        property string icon: ""
        property bool lit: false         // e.g. pinned
        property bool danger: false      // the "really delete?" state
        property real iconFill: 0
        signal clicked()

        width: 26
        height: 26
        radius: 9
        color: btn.danger ? Theme.irisColorPink
             : (btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.7) : (btn.lit ? Qt.rgba(1, 1, 1, 0.45) : "transparent"))

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        MaterialIcon {
            anchors.centerIn: parent
            name: btn.icon
            size: 18
            weight: 600
            fill: btn.iconFill
            color: Theme.colBorder
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    HoverHandler {
        id: hover
    }

    Loader {
        anchors.fill: parent
        active: note.mine
        sourceComponent: face
    }

    Component {
        id: face

        Item {
            id: ui

            // Ring and fill sizes of the paper (see Pill): the content sits inside them.
            readonly property real pad: 12
            readonly property real headH: 30
            readonly property real textTop: 8 + ui.headH + 4
            readonly property real textBottom: 16

            property bool colorOpen: false
            property bool confirmDelete: false

            readonly property bool showKeys: (hover.hovered || edit.activeFocus || ui.colorOpen) && !note.busy

            Connections {
                target: hover
                function onHoveredChanged() {
                    if (!hover.hovered) {
                        ui.colorOpen = false
                        ui.confirmDelete = false
                    }
                }
            }

            onShowKeysChanged: {
                if (!ui.showKeys) {
                    ui.colorOpen = false
                    ui.confirmDelete = false
                }
            }

            Timer {
                id: confirmTimer
                interval: 2500
                onTriggered: ui.confirmDelete = false
            }

            Component.onCompleted: {
                edit.text = note.body
                if (NotesService.freshId === note.nid)
                    edit.forceActiveFocus()
            }

            // ===== the paper =====
            Pill {
                anchors.fill: parent
                cornerRadius: 14
                ringWidth: Theme.borderWidth + 3
                ringColorTop: Qt.lighter(note.paper, 1.12)
                ringColorBottom: ringColorTop
                fillColor: note.paper
            }

            // ===== header =====
            // The drag area is the WHOLE header; the keys sit on top of it and take
            // their own presses.
            Item {
                id: header
                x: ui.pad
                y: 8
                width: note.width - ui.pad * 2
                height: ui.headH

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    cursorShape: dragArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property point startPt: Qt.point(0, 0)
                    property var startRect: null

                    function finish() {
                        if (!note.moving)
                            return
                        note.moving = false
                        dragArea.startRect = null
                        NotesService.interacting = false
                        NotesService.commit()
                    }

                    onPressed: mouse => {
                        note.raiseMe()
                        edit.focus = false
                        const p = dragArea.mapToItem(note.room, mouse.x, mouse.y)
                        dragArea.startPt = Qt.point(p.x, p.y)
                        dragArea.startRect = NotesService.geometryOf(note.nid)
                        NotesService.interacting = true
                        note.moving = true
                    }

                    onPositionChanged: mouse => {
                        if (!dragArea.pressed || !dragArea.startRect)
                            return
                        const p = dragArea.mapToItem(note.room, mouse.x, mouse.y)
                        const r = NM.move(dragArea.startRect, p.x - dragArea.startPt.x, p.y - dragArea.startPt.y, note.roomW, note.roomH)
                        NotesService.setGeometry(note.nid, r.x, r.y, r.w, r.h)
                    }

                    onReleased: dragArea.finish()
                    onCanceled: dragArea.finish()
                }

                // What the header says while the keys are away: a grip, and the pin
                // when the note is pinned.
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    opacity: ui.showKeys ? 0 : 0.55

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    MaterialIcon {
                        name: "drag_indicator"
                        size: 18
                        weight: 600
                        color: note.ink
                    }

                    MaterialIcon {
                        visible: note.pinned
                        name: "push_pin"
                        size: 16
                        fill: 1
                        weight: 600
                        color: note.ink
                    }
                }

                // The four keys.
                Row {
                    id: keys
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: opacity > 0.01 && !ui.colorOpen
                    opacity: ui.showKeys && !ui.colorOpen ? 1 : 0
                    enabled: ui.showKeys && !ui.colorOpen

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    NoteBtn {
                        icon: "add"
                        onClicked: NotesService.add("")
                    }

                    NoteBtn {
                        icon: "palette"
                        onClicked: ui.colorOpen = true
                    }

                    NoteBtn {
                        icon: "push_pin"
                        lit: note.pinned
                        iconFill: note.pinned ? 1 : 0
                        onClicked: NotesService.togglePinned(note.nid)
                    }

                    NoteBtn {
                        icon: ui.confirmDelete ? "delete_forever" : "delete"
                        danger: ui.confirmDelete
                        onClicked: {
                            // An empty note goes at once; one with text asks first.
                            if (note.body.trim() === "" || ui.confirmDelete) {
                                NotesService.remove(note.nid)
                            } else {
                                ui.confirmDelete = true
                                confirmTimer.restart()
                            }
                        }
                    }
                }

                // The colours, in place of the keys while the palette is open.
                Row {
                    id: swatches
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: ui.colorOpen
                    enabled: ui.colorOpen

                    Repeater {
                        model: NM.COLORS

                        Rectangle {
                            id: sw

                            required property var modelData
                            readonly property bool current: sw.modelData.id === note.tint

                            width: 22
                            height: 22
                            radius: 11
                            color: sw.modelData.paper
                            border.width: sw.current ? 3 : 2
                            border.color: sw.current ? Theme.colBorder : Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.45)
                            scale: swArea.containsMouse ? 1.15 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 100 }
                            }

                            MouseArea {
                                id: swArea
                                anchors.fill: parent
                                anchors.margins: -2
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    NotesService.setColor(note.nid, sw.modelData.id)
                                    ui.colorOpen = false
                                }
                            }
                        }
                    }

                    NoteBtn {
                        icon: "close"
                        onClicked: ui.colorOpen = false
                    }
                }
            }

            // ===== the text =====
            Flickable {
                id: flick
                x: ui.pad
                y: ui.textTop
                width: note.width - ui.pad * 2
                height: Math.max(0, note.height - ui.textTop - ui.textBottom)
                clip: true
                // Not draggable: a drag in the text selects it. The wheel scrolls.
                interactive: false
                contentWidth: width
                contentHeight: edit.height
                boundsBehavior: Flickable.StopAtBounds

                function clampY(y) {
                    return Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y))
                }

                onHeightChanged: flick.contentY = flick.clampY(flick.contentY)

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => flick.contentY = flick.clampY(flick.contentY - Theme.wheelPx(event))
                }

                TextEdit {
                    id: edit
                    width: flick.width
                    height: Math.max(flick.height, edit.contentHeight)
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: note.ink
                    selectionColor: Theme.accentCyan
                    selectedTextColor: Theme.colBorder
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    onTextChanged: {
                        if (edit.text.length > NM.MAX_CHARS) {
                            // The most a note keeps (see NotesMath.MAX_CHARS).
                            const c = edit.cursorPosition
                            edit.text = edit.text.slice(0, NM.MAX_CHARS)
                            edit.cursorPosition = Math.min(c, edit.text.length)
                        } else if (edit.text !== note.body) {
                            NotesService.setText(note.nid, edit.text)
                        }
                    }

                    onCursorRectangleChanged: {
                        const r = edit.cursorRectangle
                        if (r.y < flick.contentY)
                            flick.contentY = flick.clampY(r.y)
                        else if (r.y + r.height > flick.contentY + flick.height)
                            flick.contentY = flick.clampY(r.y + r.height - flick.height)
                    }

                    onActiveFocusChanged: {
                        if (edit.activeFocus)
                            note.raiseMe()
                    }

                    Keys.onEscapePressed: {
                        edit.focus = false
                        note.forceActiveFocus()
                    }

                    // Text changed from outside (a script, a reload): show it, but never
                    // while this very field is the one being typed in.
                    Connections {
                        target: note
                        function onBodyChanged() {
                            if (edit.text !== note.body && !edit.activeFocus)
                                edit.text = note.body
                        }
                    }
                }
            }

            Text {
                x: ui.pad
                y: ui.textTop
                visible: edit.text === "" && !edit.activeFocus
                text: "write something…"
                color: note.ink
                opacity: 0.45
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            // Slim scroll indicator, only when the text overflows.
            Rectangle {
                visible: flick.contentHeight > flick.height + 1
                x: note.width - ui.pad - width + 4
                y: flick.y + flick.visibleArea.yPosition * flick.height
                width: 4
                height: Math.max(20, flick.visibleArea.heightRatio * flick.height)
                radius: 2
                color: note.ink
                opacity: 0.35
            }

            // ===== resizing =====
            // The right edge, the bottom edge and the corner. None of them is on the
            // header, the text or a key.
            Repeater {
                model: ["r", "b", "rb"]

                MouseArea {
                    id: rz

                    required property string modelData
                    readonly property string edge: rz.modelData

                    // r:  the strip down the right edge, below the header, above the corner
                    // b:  the strip along the bottom, left of the corner
                    // rb: the corner square (the grip is drawn in it)
                    x: rz.edge === "b" ? ui.pad : (rz.edge === "r" ? note.width - ui.pad : note.width - 26)
                    y: rz.edge === "r" ? ui.textTop : (rz.edge === "b" ? note.height - ui.textBottom : note.height - 26)
                    width: rz.edge === "b" ? Math.max(0, note.width - ui.pad - 26) : (rz.edge === "r" ? ui.pad - 2 : 22)
                    height: rz.edge === "r" ? Math.max(0, note.height - ui.textTop - 30) : (rz.edge === "b" ? ui.textBottom - 4 : 22)

                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    cursorShape: rz.edge === "r" ? Qt.SizeHorCursor : (rz.edge === "b" ? Qt.SizeVerCursor : Qt.SizeFDiagCursor)

                    property point startPt: Qt.point(0, 0)
                    property var startRect: null

                    function finish() {
                        if (!note.resizing)
                            return
                        note.resizing = false
                        rz.startRect = null
                        NotesService.interacting = false
                        NotesService.commit()
                    }

                    onPressed: mouse => {
                        note.raiseMe()
                        edit.focus = false
                        const p = rz.mapToItem(note.room, mouse.x, mouse.y)
                        rz.startPt = Qt.point(p.x, p.y)
                        rz.startRect = NotesService.geometryOf(note.nid)
                        NotesService.interacting = true
                        note.resizing = true
                    }

                    onPositionChanged: mouse => {
                        if (!rz.pressed || !rz.startRect)
                            return
                        const p = rz.mapToItem(note.room, mouse.x, mouse.y)
                        const r = NM.resize(rz.startRect, p.x - rz.startPt.x, p.y - rz.startPt.y, rz.edge, note.roomW, note.roomH)
                        NotesService.setGeometry(note.nid, r.x, r.y, r.w, r.h)
                    }

                    onReleased: rz.finish()
                    onCanceled: rz.finish()

                    // The grip: two short diagonal strokes in the corner, only on the corner
                    // zone, a little stronger while the pointer is on the note.
                    Item {
                        visible: rz.edge === "rb"
                        anchors.fill: parent
                        opacity: hover.hovered || note.resizing ? 0.7 : 0.3

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }

                        Rectangle {
                            width: 14
                            height: 2.5
                            radius: 1.25
                            color: note.ink
                            x: 6
                            y: 14
                            rotation: -45
                            transformOrigin: Item.Center
                        }

                        Rectangle {
                            width: 7
                            height: 2.5
                            radius: 1.25
                            color: note.ink
                            x: 12
                            y: 15.5
                            rotation: -45
                            transformOrigin: Item.Center
                        }
                    }
                }
            }
        }
    }
}
