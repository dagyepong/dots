import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The chat: a small glass window above everything. He takes a big leap up,
// lands where its top left corner will be and melts into it; the window grows
// out of him and he stays in its corner as a round bump with his face, joined
// by a soft fillet, while you talk. On closing it shrinks back into him and he
// jumps down. The surface is a strip along the bottom like the others;
// only the card and his body take input.
PanelWindow {
    id: win
    required property var world
    required property var st             // the character in the chat (the first one)
    required property var brain
    signal send(string text)
    signal forget()
    signal pickModel(string name)
    signal runAction(string aid, string cmd)
    signal declineAction(string aid)
    // the window as a small terminal (Commands.qml): commands run in the scene,
    // "!…" in a shell (aiboud), anything else goes to the AI
    property var commands: null
    signal runShell(string id, string cmd)
    signal killShell()
    property var past: []                // lines typed, for ↑ ↓
    property bool legendOpen: false
    onVisibleChanged: if (!visible) legendOpen = false
    property int pastAt: -1
    function debug() {
        return JSON.stringify({ visible: visible, w: width, h: height, grow: [growW, growH, contentIn, seated], card: [card.x, card.y, card.width, card.height, card.opacity, card.visible],
                                jumpT: jumpT, fig: [figX, figY, figOn], floor: floor, input: input.text, focus: input.activeFocus, grab: grab, sticky: sticky })
    }

    readonly property bool de: world.lang === "de"
    function tx(de, en, ja) { return world.tr(de, en, ja) }
    // from fixed sizes: the surface has none yet when it is mapped
    readonly property real floor: implicitHeight - world.insets.bottom

    // always mapped: unmapping a surface can crash Qt (handleScreensChanged);
    // closed, it draws nothing and takes no input
    visible: true
    anchors { left: true; right: true; bottom: true }
    // the whole screen high, so the card can be dragged anywhere
    implicitHeight: world.areaH
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aibou-chat"
    // The keyboard: niri gives an on-demand layer the keyboard only on a click
    // and takes it away when the mode changes, so the chat holds it
    // exclusively while it is wanted: from opening until the pointer moves well
    // away, and again whenever the pointer is over the card. Away from it, the
    // window under the pointer gets the keyboard back.
    property bool sticky: false
    property bool pointerOver: false
    readonly property bool grab: world.chatOpen && (sticky || pointerOver || cardHover.hovered)
    WlrLayershell.keyboardFocus: !world.chatOpen ? WlrKeyboardFocus.None
                                 : grab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    onGrabChanged: if (grab) input.forceActiveFocus()
    function focusInput() {
        sticky = true
        input.forceActiveFocus()
    }
    // global pointer position (from the niri pointer stream)
    function pointerAt(gx, gy) {
        if (!screen) return
        const x = gx - screen.x, y = gy - (screen.y + screen.height - implicitHeight)
        const over = x >= card.x && x <= card.x + card.width && y >= card.y && y <= card.y + card.height
        if (over !== pointerOver) pointerOver = over
        const m = 90
        if (sticky && (x < card.x - m || x > card.x + card.width + m || y < card.y - m || y > card.y + card.height + m))
            sticky = false
    }

    mask: Region {
        item: world.chatOpen && win.contentIn > 0.5 ? card : null
        Region { item: figHit }
    }
    BackgroundEffect.blurRegion: Region {
        // never empty: niri blurs a whole surface whose region is empty
        item: blurAnchor
        Region { item: win.shown ? boxItem : null; radius: win.boxRad }
        Region { shape: RegionShape.Ellipse; item: bumpItem }
        Region { shape: RegionShape.Ellipse; item: figGlass }
    }

    // ── icons from the DMS font, plain glyphs if it is missing ────
    FontLoader {
        id: symbols
        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/dms-custom/DankCommon/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    }
    readonly property bool haveSymbols: symbols.status === FontLoader.Ready
    component Glyph: Text {
        property string icon: ""
        property string fallback: ""
        text: win.haveSymbols ? icon : fallback
        font.family: win.haveSymbols ? symbols.name : ""
        font.pixelSize: win.haveSymbols ? 20 : 16
        color: win.world.bubbleText
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
    component Button: Rectangle {
        id: btn
        property string icon: ""
        property string fallback: ""
        property string label: ""
        property string tip: ""
        property bool active: false          // a panel it opens is open
        signal clicked()
        height: 30
        width: label === "" ? 30 : row.implicitWidth + 18
        radius: 15
        color: active ? Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.22)
             : ma.containsMouse ? Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, 0.12) : "transparent"
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4
            Glyph { icon: btn.icon; fallback: btn.fallback; visible: btn.icon !== ""; height: 30; color: win.world.outline }
            Text {
                visible: btn.label !== ""
                text: btn.label
                color: win.world.bubbleText
                font.pixelSize: 12
                font.weight: Font.Medium
                height: 30
                verticalAlignment: Text.AlignVCenter
            }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    // ── the card ─────────────────────────────────────────────────
    // ── him in its corner, and the card growing out of him ────────
    property bool seated: false          // melted into the corner: the bump stands for him
    // the window open without him: he jumped out (for a command, by the button,
    // dragged out by the pointer) and the card stays; he comes back by jumping in
    property bool away: false
    // the activity menu in the header
    property bool actOpen: false
    property real actClosedAt: 0
    onLegendOpenChanged: actOpen = false
    function actIcon(a) { return ({ minimal: "bedtime", calm: "spa", normal: "sentiment_satisfied", lively: "directions_run", max: "rocket_launch" })[a] || "sentiment_satisfied" }
    function actLabel(a) {
        const n = ({ minimal: ["Minimal", "Minimal", "最小"], calm: ["Ruhig", "Calm", "おだやか"], normal: ["Normal", "Normal", "ふつう"], lively: ["Lebhaft", "Lively", "元気"], max: ["Maximal", "Maximal", "最大"] })[a] || ["Normal", "Normal", "ふつう"]
        return win.tx(n[0], n[1], n[2])
    }
    function actHint(a) {
        const n = ({ minimal: ["im Rahmen, schaut nur zu", "in the frame, just watches", "フレームの中で見てるだけ"],
                     calm: ["schmilzt schnell ein, selten unterwegs", "melts in soon, rarely about", "すぐとけこむ、あまり出歩かない"],
                     normal: ["mal unterwegs, mal im Rahmen", "now about, now in the frame", "出歩いたり、フレームにいたり"],
                     lively: ["oft unterwegs, schmilzt spät ein", "often about, melts in late", "よく出歩く、なかなかとけこまない"],
                     max: ["immer unterwegs, ruft Freunde", "always about, calls friends", "いつも出歩いて、仲間を呼ぶ"] })[a] || ["", "", ""]
        return win.tx(n[0], n[1], n[2])
    }
    // the card is there while he sits in it or is out of it; the round bump only while he sits
    readonly property bool shown: seated || away
    readonly property real seatR: seated ? bumpR : 0
    onAwayChanged: win.world.chatAway = away
    // out of the corner, down in front of the windows beside the card
    function hopOut() {
        if (!seated || jumpInAnim.running || jumpOutAnim.running) return
        away = true
        const left = card.x - st.size, right = card.x + card.width + st.size
        fromX = left > world.insets.left + st.size ? left : Math.min(world.areaW - world.insets.right - st.size, right)
        seated = false
        jumpOutAnim.start()
    }
    // pulled out of the corner by the pointer: the brain takes him from here
    function pulledOut() {
        jumpInAnim.stop(); jumpOutAnim.stop()
        away = true
        seated = false
        jumpT = 0; drop = 0
    }
    // the window closes while he is out: it folds away by itself
    SequentialAnimation {
        id: collapseAnim
        NumberAnimation { target: win; property: "contentIn"; to: 0; duration: 140 }
        ParallelAnimation {
            NumberAnimation { target: win; property: "growH"; to: 0; duration: 240; easing.type: Easing.InQuad }
            NumberAnimation { target: win; property: "growW"; to: 0; duration: 240; easing.type: Easing.InQuad }
        }
    }
    property real growW: 0               // 0: the card is only his circle; 1: full size
    property real growH: 0
    property real contentIn: 0
    readonly property real bumpR: st.size * 0.72 * bumpPop
    readonly property real bumpCX: card.x + 16
    readonly property real bumpCY: card.y + 16
    function mixed(a, b, t) { return a + (b - a) * t }
    readonly property real boxX: mixed(bumpCX - bumpR, card.x, growW)
    readonly property real boxY: mixed(bumpCY - bumpR, card.y, growH)
    readonly property real boxW: mixed(2 * bumpR, card.width, growW)
    readonly property real boxH: mixed(2 * bumpR, card.height, growH)
    readonly property real boxRad: Math.min(boxW, boxH) < 2 * bumpR + 1 ? Math.min(boxW, boxH) / 2
                                   : mixed(bumpR, card.radius, Math.min(1, Math.min(growW, growH) * 1.6))
    SequentialAnimation {
        id: growAnim
        ParallelAnimation {
            NumberAnimation { target: win; property: "bumpPop"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            NumberAnimation { target: win; property: "growW"; to: 1; duration: 420; easing.type: Easing.OutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 70 }
                NumberAnimation { target: win; property: "growH"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            SequentialAnimation {
                PauseAnimation { duration: 380 }
                NumberAnimation { target: win; property: "contentIn"; to: 1; duration: 220; easing.type: Easing.OutQuad }
            }
        }
        ScriptAction { script: win.world.chatSeated(win.st) }
    }
    SequentialAnimation {
        id: shrinkAnim
        NumberAnimation { target: win; property: "contentIn"; to: 0; duration: 120 }
        ParallelAnimation {
            NumberAnimation { target: win; property: "growH"; to: 0; duration: 300; easing.type: Easing.InQuad }
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                NumberAnimation { target: win; property: "growW"; to: 0; duration: 280; easing.type: Easing.InQuad }
            }
        }
        ScriptAction { script: { win.seated = false; jumpOutAnim.start() } }
    }
    // the shape: card and bump in one, drawn only where they are
    readonly property real shapePad: 4
    ShaderEffect {
        id: blobCard
        visible: win.shown
        x: win.bumpCX - win.bumpR - win.shapePad
        y: win.bumpCY - win.bumpR - win.shapePad
        width: Math.max(win.boxX + win.boxW, win.bumpCX + win.bumpR) - x + win.shapePad
        height: Math.max(win.boxY + win.boxH, win.bumpCY + win.bumpR) - y + win.shapePad
        property size size: Qt.size(width, height)
        property rect box: Qt.rect(win.boxX - x, win.boxY - y, win.boxW, win.boxH)
        property real radius: win.boxRad
        property vector4d circ: Qt.vector4d(win.bumpCX - x, win.bumpCY - y, win.seatR, 0)
        property real k: win.seatR * 0.55
        property color fill: Qt.rgba(win.world.bubbleBg.r, win.world.bubbleBg.g, win.world.bubbleBg.b, Math.max(0.82, win.world.glassOpacity))
        property color line: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.45)
        property real lineW: 1
        fragmentShader: "shaders/blobcard.frag.qsb"
    }
    Item { id: blurAnchor; width: 1; height: 1 }
    Item { id: boxItem; x: win.boxX; y: win.boxY; width: win.boxW; height: win.boxH }
    Item {
        id: bumpItem
        readonly property real r: win.seated ? win.bumpR : 0
        x: win.bumpCX - r; y: win.bumpCY - r; width: 2 * r; height: 2 * r
    }
    // where it sits: above him, a little to the right, inside the frame (with
    // room for him in its corner)
    // size and place, kept across restarts (~/.local/state/aibou/chatwin.json):
    // dragged by its head it stays where it was put, otherwise it opens over him
    FileView {
        id: winFile
        path: Quickshell.env("HOME") + "/.local/state/aibou/chatwin.json"
        watchChanges: false
        printErrors: false
        JsonAdapter {
            id: saved
            property real w: 460
            property real h: 600
            property real x: -1
            property real y: -1
        }
    }
    readonly property real minW: 340
    readonly property real minH: 380
    function clampSize() {
        card.width = Math.max(minW, Math.min(world.areaW - world.insets.left - world.insets.right - bumpR - 24, saved.w))
        card.height = Math.max(minH, Math.min(floor - world.insets.top - bumpR - 24, saved.h))
    }
    function keepPlace(moved) {
        saved.w = card.width; saved.h = card.height
        if (moved) { saved.x = card.x; saved.y = card.y }
        winFile.writeAdapter()
    }
    function place() {
        clampSize()
        const w = card.width
        const left = world.insets.left + 12 + bumpR, right = world.areaW - world.insets.right - 12 - w
        const top = world.insets.top + bumpR, bottom = floor - card.height - 8
        if (saved.x >= 0) {
            card.x = Math.max(left, Math.min(right, saved.x))
            card.y = Math.max(top, Math.min(bottom, saved.y))
            return
        }
        card.x = Math.max(left, Math.min(right, st.x0 - 70))
        card.y = Math.max(top, floor - 84 - card.height)
    }
    Connections {
        target: win.world
        // the keyboard right away, typing can start while he is still jumping
        function onChatOpenChanged() {
            if (win.world.chatOpen) { if (!win.away) win.place(); win.focusInput() }
            else {
                win.sticky = false; win.pointerOver = false
                if (win.away) { win.away = false; collapseAnim.start() }
            }
        }
    }

    Rectangle {
        id: card
        width: 460
        height: 600
        radius: 22
        // the shape behind (blobCard) is its glass; this holds what is in it
        opacity: win.contentIn
        visible: opacity > 0.01
        color: "transparent"
        HoverHandler { id: cardHover }

        // ── header: his seat, name, what he is doing, buttons ──
        Item {
            id: header
            width: parent.width
            height: 92
            DragHandler {
                target: card
                xAxis.minimum: win.world.insets.left + win.bumpR
                xAxis.maximum: win.world.areaW - win.world.insets.right - card.width
                yAxis.minimum: win.world.insets.top + win.bumpR
                yAxis.maximum: win.floor - card.height - 8
                cursorShape: Qt.ClosedHandCursor
                onActiveChanged: if (!active) win.keepPlace(true)
            }
            // where he lands: his body's centre on the bump's (feet below it)
            readonly property real seatX: 16
            readonly property real seatY: 16 + win.st.size * 0.5
            Column {
                x: 16 + win.bumpR + 26
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                spacing: 2
                Text {
                    text: win.st.name
                    color: win.world.bubbleText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Text {
                    text: (win.world.chatBusy ? win.tx("denkt nach …", "thinking …", "考え中 …")
                                              : win.tx("hört zu", "listening", "聞いてるよ"))
                          + "  ·  " + (win.world.dnd ? win.tx("Nicht stören", "Do not disturb", "おやすみモード") : win.actLabel(win.world.activity))
                    color: win.world.outline
                    font.pixelSize: 12
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 4
                spacing: 2
                Button {
                    // how lively they are, without opening the settings
                    id: actBtn
                    icon: win.actIcon(win.world.activity); fallback: "≈"
                    active: win.actOpen
                    onClicked: if (Date.now() - win.actClosedAt > 400) win.actOpen = !win.actOpen
                }
                Button {
                    // him out of the window (it stays open), or back in
                    icon: win.away ? "login" : "logout"; fallback: win.away ? "↩" : "↪"
                    onClicked: win.away ? win.brain.openChat() : win.hopOut()
                }
                Button {
                    // the legend: every command, to click
                    icon: "apps"; fallback: "☰"
                    active: win.legendOpen
                    onClicked: win.legendOpen = !win.legendOpen
                }
                Button {
                    // Haiku answers fastest; Sonnet and Opus think deeper; then the other providers
                    label: win.world.modelLabel(win.world.chatModel)
                    icon: "bolt"; fallback: ""
                    onClicked: {
                        const order = win.world.modelChoices
                        const next = order[(order.indexOf(win.world.chatModel) + 1) % order.length]
                        win.world.chatModel = next
                        win.pickModel(next)
                    }
                }
                Button {
                    // empties the window; what he remembers stays ("forget" deletes it)
                    icon: "clear_all"; fallback: "↺"
                    onClicked: { win.runLine("clear"); win.focusInput() }
                }
                Button {
                    icon: "close"; fallback: "✕"
                    onClicked: win.brain.closeChat()
                }
            }
        }
        // a click anywhere else closes the activity menu (and still does what it hits)
        MouseArea {
            z: 19
            anchors.fill: parent
            visible: win.actOpen
            onPressed: mouse => { win.actOpen = false; win.actClosedAt = Date.now(); mouse.accepted = false }
        }
        // the activity levels, dropped down under their button
        Rectangle {
            id: actMenu
            z: 20
            visible: win.actOpen
            x: card.width - width - 12
            y: header.height - 10
            width: 230
            height: actCol.implicitHeight + 12
            radius: 14
            color: Qt.rgba(win.world.bubbleBg.r, win.world.bubbleBg.g, win.world.bubbleBg.b, 0.98)
            border.width: 1
            border.color: Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.35)
            Column {
                id: actCol
                x: 6; y: 6
                width: parent.width - 12
                Repeater {
                    model: win.world.activities
                    Rectangle {
                        id: actRow
                        required property string modelData
                        readonly property bool chosen: win.world.activity === modelData
                        width: actCol.width; height: 46; radius: 10
                        color: actRowMa.containsMouse ? Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, 0.1)
                             : chosen ? Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.18) : "transparent"
                        Glyph {
                            x: 8; width: 26; height: parent.height
                            icon: win.actIcon(actRow.modelData); fallback: "•"
                            color: actRow.chosen ? win.world.primary : win.world.outline
                        }
                        Column {
                            x: 42; width: parent.width - 50
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: win.actLabel(actRow.modelData); color: win.world.bubbleText; font.pixelSize: 13; font.weight: actRow.chosen ? Font.DemiBold : Font.Normal }
                            Text { text: win.actHint(actRow.modelData); color: win.world.outline; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                        }
                        MouseArea {
                            id: actRowMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { win.world.activityTest = ""; win.world.setOption("activity", actRow.modelData); win.actOpen = false; win.focusInput() }
                        }
                    }
                }
            }
        }
        Rectangle {
            y: header.height
            x: 16; width: parent.width - 32; height: 1
            color: Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.25)
        }

        // ── the conversation ──
        ListView {
            id: list
            y: header.height + 8
            x: 14
            width: parent.width - 28
            height: inputBox.y - y - 8
            clip: true
            spacing: 8
            // under the open legend the log would shine through its glass
            visible: !win.legendOpen
            model: win.world.chatLog
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(positionViewAtEnd)
            onContentHeightChanged: if (atYEnd || win.world.chatBusy) Qt.callLater(positionViewAtEnd)

            // an empty chat says hello
            Text {
                visible: list.count === 0
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: win.tx("Schreib mir was. Enter schickt, Shift+Enter macht eine neue Zeile, Esc schließt.\nBefehle wie kiss, dance, angry 3 laufen sofort, !befehl in der Shell. help zeigt alle.",
                             "Write me something. Enter sends, Shift+Enter starts a new line, Esc closes.\nCommands like kiss, angry 3 run right away, !command in a shell. help lists them.",
                             "なにか書いてね。Enter で送信、Shift+Enter で改行、Esc で閉じる。\nkiss、dance、angry 3 などのコマンドはすぐ動くよ。!コマンド はシェルで。help で一覧。")
                color: win.world.outline
                font.pixelSize: 13
            }

            delegate: Item {
                id: row
                required property int index
                required property string who
                required property string text
                required property bool pending
                required property string aid
                required property string phase
                required property string out
                readonly property bool mine: who === "me"
                readonly property bool note: who === "note" || who === "tool"
                readonly property bool action: who === "action"
                readonly property bool term: who === "cmd" || who === "shell"
                width: list.width
                height: action ? actionCard.height : term ? termBox.height : bubble.height
                readonly property real maxW: note ? width : width * 0.84

                // a command or a shell line, terminal-like: what was typed, then the answer
                    Rectangle {
                    id: termBox
                    visible: row.term
                    width: row.width
                    height: termCol.implicitHeight + 14
                    radius: 10
                    color: win.world.dark ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, 0.07)
                    Column {
                        id: termCol
                        x: 10; y: 7
                        width: termBox.width - 20
                        spacing: 3
                        TextEdit {
                            width: parent.width
                            text: (row.who === "shell" ? "$ " : "› ") + row.text
                            readOnly: true; selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            font.family: "monospace"; font.pixelSize: 13
                            color: win.world.primary
                            selectionColor: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.5)
                        }
                        TextEdit {
                            visible: text !== ""
                            width: parent.width
                            text: row.out !== "" ? row.out.replace(/\n+$/, "")
                                : row.phase === "running" ? "…" : ""
                            readOnly: true; selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            font.family: "monospace"; font.pixelSize: 12
                            color: row.phase === "failed" ? "#e06c75" : win.world.bubbleText
                            selectionColor: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.5)
                        }
                    }
                }

                Rectangle {
                    id: bubble
                    visible: !row.action && !row.term
                    x: row.mine ? row.width - width : 0
                    width: Math.min(row.maxW, Math.max(measure.implicitWidth, row.pending && row.text === "" ? 34 : 0) + 24)
                    height: content.height + (row.note ? 10 : 16)
                    radius: 14
                    color: row.note ? "transparent"
                         : row.mine ? Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.22)
                         : Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, 0.07)
                    border.width: row.who === "note" ? 1 : 0
                    border.color: Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.3)
                    // to measure the unwrapped width
                    Text {
                        id: measure
                        visible: false
                        text: content.text
                        textFormat: row.mine || row.note ? Text.PlainText : Text.MarkdownText
                        font.pixelSize: row.note ? 12 : 14
                        font.family: row.who === "tool" ? "monospace" : ""
                    }
                    TextEdit {
                        id: content
                        visible: row.text !== ""
                        x: 12; y: row.note ? 5 : 8
                        width: bubble.width - 24
                        // what he looks up, in a few words
                        text: row.who === "tool" ? "› " + row.text : row.text
                        textFormat: row.mine || row.note ? TextEdit.PlainText : TextEdit.MarkdownText
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        selectionColor: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.5)
                        color: row.note ? win.world.outline : win.world.bubbleText
                        font.pixelSize: row.note ? 12 : 14
                        font.family: row.who === "tool" ? "monospace" : ""
                    }
                    // three dots while the first words are on their way
                    Row {
                        visible: row.pending && row.text === ""
                        x: 12; y: 8
                        height: 20
                        spacing: 5
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6; height: 6; radius: 3
                                color: win.world.bubbleText
                                opacity: win.dot === index ? 0.9 : 0.3
                            }
                        }
                    }
                }

                // a change he proposes: nothing happens until it is confirmed
                Rectangle {
                    id: actionCard
                    visible: row.action
                    width: row.width
                    height: cardCol.implicitHeight + 20
                    radius: 14
                    color: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, row.phase === "ask" ? 0.10 : 0.05)
                    border.width: 1
                    border.color: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, row.phase === "ask" ? 0.55 : 0.25)
                    Column {
                        id: cardCol
                        x: 12; y: 10
                        width: actionCard.width - 24
                        spacing: 8
                        Text {
                            text: ({
                                ask: win.tx("Vorschlag", "Proposal", "提案"),
                                running: win.tx("läuft …", "running …", "実行中 …"),
                                done: win.tx("erledigt", "done", "完了"),
                                failed: win.tx("fehlgeschlagen", "failed", "失敗"),
                                declined: win.tx("abgelehnt", "declined", "見送り"),
                                blocked: win.tx("gesperrt", "blocked", "ブロック")
                            })[row.phase] || ""
                            color: row.phase === "failed" || row.phase === "blocked" ? "#e06c75" : win.world.primary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                        }
                        TextEdit {
                            width: parent.width
                            text: row.text
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            font.family: "monospace"
                            font.pixelSize: 13
                            color: win.world.bubbleText
                            selectionColor: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.5)
                        }
                        TextEdit {
                            visible: row.out !== ""
                            width: parent.width
                            text: row.out
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: win.world.outline
                        }
                        Row {
                            visible: row.phase === "ask"
                            spacing: 8
                            Rectangle {
                                width: runLabel.implicitWidth + 24; height: 30; radius: 15
                                color: runMa.containsMouse ? Qt.lighter(win.world.primary, 1.1) : win.world.primary
                                Text {
                                    id: runLabel
                                    anchors.centerIn: parent
                                    text: win.tx("Ausführen", "Run", "実行")
                                    color: win.world.dark ? "#1a1412" : "white"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: runMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.world.chatLog.setProperty(row.index, "phase", "running")
                                        win.runAction(row.aid, row.text)
                                    }
                                }
                            }
                            Rectangle {
                                width: noLabel.implicitWidth + 24; height: 30; radius: 15
                                color: noMa.containsMouse ? Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, 0.12) : "transparent"
                                border.width: 1
                                border.color: Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.5)
                                Text {
                                    id: noLabel
                                    anchors.centerIn: parent
                                    text: win.tx("Lieber nicht", "Not now", "やめておく")
                                    color: win.world.bubbleText
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    id: noMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.world.chatLog.setProperty(row.index, "phase", "declined")
                                        win.declineAction(row.aid)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        property int dotStep: 0

        // ── the legend: every command to click ──
        // Who does it (and with whom, and how strongly) is chosen at the top;
        // a click runs the command as if typed, so it shows in the log too.
        Rectangle {
            id: legend
            visible: win.legendOpen
            x: 10; y: header.height + 4
            width: parent.width - 20
            height: inputBox.y - y - 6
            radius: 14
            z: 5
            color: win.world.dark ? Qt.rgba(0.08, 0.07, 0.07, 0.96) : Qt.rgba(0.98, 0.97, 0.96, 0.97)
            border.width: 1
            border.color: Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.35)
            // swallow clicks and wheel so nothing reaches the log below
            MouseArea { anchors.fill: parent; onWheel: wheel => wheel.accepted = true }

            readonly property var figs: win.commands ? win.commands.active().map(b => b.st.name) : []
            property string actor: ""            // "" the first one, "all"
            property string partner: ""          // "" the nearest one
            property int level: 2
            property string hint: ""
            readonly property var groups: win.commands && win.legendOpen ? win.commands.legend() : []
            function nameOf(n) { return n.toLowerCase() }
            function commandFor(item) {
                const a = actor === "" ? "" : nameOf(actor)
                if (item.kind === "pair") {
                    if (actor === "all") return null
                    if (partner === "") return item.cmd + (a ? " " + a : "")
                    return item.cmd + " " + (a || nameOf(figs[0])) + " " + nameOf(partner)
                }
                if (item.kind === "one") return item.cmd + (a ? " " + a : "")
                return item.cmd
            }
            // whose pictures the tiles show: the chosen figure, else the first one
            readonly property string actorSkin: {
                const bs = win.commands ? win.commands.active() : []
                const b = actor === "" || actor === "all" ? bs[0] : bs.find(x => x.st.name === actor)
                return b ? b.st.skin : "kuro"
            }
            readonly property var noPicIcons: ({ stop: "stop_circle", more: "person_add", fewer: "person_remove", who: "group",
                                                 models: "smart_toy", clear: "clear_all", forget: "delete_sweep", help: "help" })
            function picFor(item) {
                if (item.kind === "none") return ""
                return Qt.resolvedUrl("thumbs/" + (item.kind === "pair" || item.kind === "group" ? "pair" : actorSkin) + "/" + item.cmd + ".png")
            }
            function moodPic(m) {
                const leveled = ["happy", "angry", "sad", "scared", "blush"].indexOf(m) >= 0
                return Qt.resolvedUrl("thumbs/" + actorSkin + "/" + m + (leveled ? level : "") + ".png")
            }
            function moodCommand(m) { return m + (level !== 2 ? " " + level : "") + (actor ? " " + nameOf(actor) : "") }
            function fire(cmd) {
                if (!cmd) { hint = win.tx("Zu zweit geht nicht mit „Alle“.", "Pairs do not work with \"all\".", "ふたり用は「みんな」ではできないよ。"); return }
                win.runLine(cmd)
                hint = "› " + cmd
            }

            component Chip: Rectangle {
                id: chip
                property string text: ""
                property bool on: false
                property string tip: ""
                signal pick()
                height: 26
                width: chipText.implicitWidth + 18
                radius: 13
                color: on ? win.world.primary
                     : chipMa.containsMouse ? Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.22)
                     : Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, 0.08)
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.text
                    color: chip.on ? (win.world.dark ? "#1a1412" : "white") : win.world.bubbleText
                    font.pixelSize: 12
                    font.weight: chip.on ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: chipMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: chip.pick()
                    onContainsMouseChanged: if (containsMouse && chip.tip !== "") legend.hint = chip.tip
                }
            }
            // a command as a tile: a picture of the figure doing it (shell/thumbs,
            // made by thumbs.qml), or a symbol for those without a figure
            component Tile: Rectangle {
                id: tile
                property string label: ""
                property string pic: ""
                property string icon: ""
                property string tip: ""
                signal pick()
                width: (legendCol.width - 3 * 6) / 4
                height: width * 0.86
                radius: 12
                color: tileMa.containsMouse ? Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.2)
                     : Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, 0.07)
                border.width: tileMa.containsMouse ? 1 : 0
                border.color: win.world.primary
                Image {
                    visible: tile.pic !== ""
                    source: tile.pic
                    x: 2; y: 2
                    width: parent.width - 4
                    height: parent.height - 22
                    fillMode: Image.PreserveAspectFit
                    // the pictures leave room above the figure: show the lower part larger
                    sourceClipRect: Qt.rect(30, 40, 280, 202)
                    smooth: true
                    asynchronous: true
                    cache: true
                }
                Glyph {
                    visible: tile.pic === ""
                    icon: tile.icon; fallback: "•"
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (parent.height - 22) / 2 - height / 2 + 2
                    font.pixelSize: win.haveSymbols ? 28 : 20
                    color: win.world.outline
                }
                Text {
                    x: 4; width: parent.width - 8
                    y: parent.height - 20
                    height: 18
                    text: tile.label
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: win.world.bubbleText
                }
                MouseArea {
                    id: tileMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: tile.pick()
                    onContainsMouseChanged: if (containsMouse && tile.tip !== "") legend.hint = tile.tip
                }
            }
            component Caption: Text {
                color: win.world.outline
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                height: 26
                verticalAlignment: Text.AlignVCenter
            }

            Flickable {
                id: legendFlick
                x: 12; y: 10
                width: parent.width - 24
                height: parent.height - 20 - hintLine.height
                contentHeight: legendCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: legendCol
                    width: legendFlick.width
                    spacing: 6
                    // who, with whom, how strongly
                    Flow {
                        width: parent.width
                        spacing: 5
                        Caption { text: win.tx("Wer", "Who", "だれ"); width: 62 }
                        Repeater {
                            model: legend.figs
                            Chip {
                                required property string modelData
                                required property int index
                                text: modelData
                                on: legend.actor === (index === 0 ? "" : modelData) || (legend.actor === modelData)
                                onPick: { legend.actor = index === 0 ? "" : modelData; if (legend.partner === modelData) legend.partner = "" }
                            }
                        }
                        Chip { text: win.tx("Alle", "All", "みんな"); on: legend.actor === "all"; onPick: legend.actor = "all" }
                    }
                    Flow {
                        width: parent.width
                        spacing: 5
                        visible: legend.figs.length > 1
                        Caption { text: win.tx("Mit", "With", "相手"); width: 62 }
                        Chip { text: win.tx("Nächste", "Nearest", "近くの子"); on: legend.partner === ""; onPick: legend.partner = "" }
                        Repeater {
                            model: legend.figs
                            Chip {
                                required property string modelData
                                required property int index
                                visible: modelData !== (legend.actor === "" ? legend.figs[0] : legend.actor)
                                text: modelData
                                on: legend.partner === modelData
                                onPick: legend.partner = modelData
                            }
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 5
                        Caption { text: win.tx("Stufe", "Level", "レベル"); width: 62 }
                        Repeater {
                            model: [1, 2, 3]
                            Chip {
                                required property int modelData
                                text: [win.tx("leicht", "a little", "すこし"), win.tx("normal", "normal", "ふつう"), win.tx("sehr", "very", "とても")][modelData - 1]
                                on: legend.level === modelData
                                onPick: legend.level = modelData
                                tip: win.tx("Stärke der Stimmung, für die Stimmungen unten", "Strength of the mood, for the moods below", "下の気分の強さ")
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.25) }

                    // the commands, by group
                    Repeater {
                        model: legend.groups
                        Column {
                            id: grp
                            required property var modelData
                            width: legendCol.width
                            spacing: 4
                            Caption { text: grp.modelData.title }
                            Flow {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: grp.modelData.items
                                    Tile {
                                        required property var modelData
                                        label: modelData.label
                                        pic: legend.picFor(modelData)
                                        icon: legend.noPicIcons[modelData.cmd] || "terminal"
                                        tip: (legend.commandFor(modelData) || modelData.cmd) + "  ·  " + modelData.desc
                                        onPick: legend.fire(legend.commandFor(modelData))
                                    }
                                }
                            }
                        }
                    }
                    Column {
                        width: legendCol.width
                        spacing: 4
                        Caption { text: win.tx("Stimmung", "Mood", "気分") }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: win.commands ? win.commands.moodList : []
                                Tile {
                                    required property var modelData
                                    label: win.tx(modelData[1], modelData[2], modelData[3])
                                    pic: legend.moodPic(modelData[0])
                                    tip: legend.moodCommand(modelData[0])
                                    onPick: legend.fire(legend.moodCommand(modelData[0]))
                                }
                            }
                        }
                    }
                    Text {
                        width: legendCol.width
                        wrapMode: Text.Wrap
                        text: win.tx("Alles lässt sich auch tippen, ohne „aibou“ davor; !befehl läuft in der Shell, anderes geht an die KI.",
                                     "Everything can be typed too, without \"aibou\"; !command runs in a shell, anything else goes to the AI.",
                                     "ぜんぶ「aibou」なしで入力もできるよ。!コマンド はシェルで動き、それ以外は AI へ。")
                        color: win.world.outline
                        font.pixelSize: 11
                        topPadding: 4
                    }
                }
            }
            // what the chip under the pointer does, or what just ran
            Text {
                id: hintLine
                x: 14
                width: parent.width - 28
                y: parent.height - height - 8
                height: 18
                text: legend.hint
                elide: Text.ElideRight
                font.family: "monospace"
                font.pixelSize: 11
                color: win.world.primary
            }
        }

        // ── the grip in the lower right corner: drag to resize ──
        Item {
            id: grip
            width: 22; height: 22
            x: card.width - width - 2; y: card.height - height - 2
            z: 10
            property real startW: 0
            property real startH: 0
            Canvas {
                anchors.fill: parent
                opacity: gripHover.hovered || gripDrag.active ? 0.9 : 0.4
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    c.strokeStyle = win.world.outline
                    c.lineWidth = 1.5; c.lineCap = "round"
                    for (const d of [6, 11, 16]) { c.beginPath(); c.moveTo(width - 4, height - 4 - d); c.lineTo(width - 4 - d, height - 4); c.stroke() }
                }
            }
            HoverHandler { id: gripHover; cursorShape: Qt.SizeFDiagCursor }
            DragHandler {
                id: gripDrag
                target: null
                cursorShape: Qt.SizeFDiagCursor
                onActiveChanged: {
                    if (active) { grip.startW = card.width; grip.startH = card.height }
                    else win.keepPlace(false)
                }
                // in window coordinates: the grip moves with the card it resizes,
                // its own translation would run away
                onCentroidChanged: {
                    if (!active) return
                    const dx = centroid.scenePosition.x - centroid.scenePressPosition.x
                    const dy = centroid.scenePosition.y - centroid.scenePressPosition.y
                    const maxW = win.world.areaW - win.world.insets.right - card.x - 8
                    const maxH = win.floor - card.y - 8
                    card.width = Math.max(win.minW, Math.min(maxW, grip.startW + dx))
                    card.height = Math.max(win.minH, Math.min(maxH, grip.startH + dy))
                }
            }
        }

        // ── the input ──
        Rectangle {
            id: inputBox
            x: 14
            width: parent.width - 28
            height: Math.min(130, Math.max(44, input.contentHeight + 22))
            y: parent.height - height - 14
            radius: 16
            color: Qt.rgba(win.world.bubbleText.r, win.world.bubbleText.g, win.world.bubbleText.b, win.world.dark ? 0.06 : 0.35)
            border.width: 1
            border.color: input.activeFocus ? Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.8)
                                            : Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.35)
            Flickable {
                id: inputFlick
                x: 14; y: 11
                width: parent.width - 14 - 46
                height: parent.height - 22
                contentHeight: input.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: input
                    width: inputFlick.width
                    wrapMode: TextEdit.Wrap
                    color: win.world.bubbleText
                    selectionColor: Qt.rgba(win.world.primary.r, win.world.primary.g, win.world.primary.b, 0.5)
                    font.pixelSize: 14
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y + cursorRectangle.height > inputFlick.contentY + inputFlick.height)
                            inputFlick.contentY = cursorRectangle.y + cursorRectangle.height - inputFlick.height
                        else if (cursorRectangle.y < inputFlick.contentY)
                            inputFlick.contentY = cursorRectangle.y
                    }
                    onTextChanged: win.typing()
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            win.submit()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            if (win.legendOpen) win.legendOpen = false
                            else win.brain.closeChat()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up && input.text.indexOf("\n") < 0) {
                            win.browse(1); event.accepted = true
                        } else if (event.key === Qt.Key_Down && input.text.indexOf("\n") < 0) {
                            win.browse(-1); event.accepted = true
                        } else if (event.key === Qt.Key_Tab) {
                            if (win.commands) { input.text = win.commands.complete(input.text); input.cursorPosition = input.text.length }
                            event.accepted = true
                        } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier) && input.selectedText === "") {
                            // Ctrl+C with nothing selected stops a running shell command
                            win.killShell(); event.accepted = true
                        }
                    }
                }
                Text {
                    visible: input.text === ""
                    text: win.tx("Schreib " + win.st.name + " was … (help: Befehle)", "Say something to " + win.st.name + " … (help: commands)", win.st.name + " になにか話して … (help: コマンド)")
                    color: win.world.outline
                    font.pixelSize: 14
                }
            }
            Rectangle {
                id: sendBtn
                readonly property bool can: input.text.trim() !== "" && (!win.world.chatBusy || input.text.trim()[0] === "!")
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                width: 30; height: 30; radius: 15
                color: can ? win.world.primary : Qt.rgba(win.world.outline.r, win.world.outline.g, win.world.outline.b, 0.25)
                Glyph {
                    anchors.centerIn: parent
                    icon: "arrow_upward"; fallback: "↑"
                    color: sendBtn.can ? (win.world.dark ? "#1a1412" : "white") : win.world.outline
                    font.pixelSize: win.haveSymbols ? 18 : 15
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.submit() }
            }
        }
    }
    readonly property int dot: card.dotStep
    Timer {
        interval: 280; repeat: true
        running: win.world.chatBusy && win.visible
        onTriggered: card.dotStep = (card.dotStep + 1) % 3
    }

    function submit() {
        const t = input.text.trim()
        if (t === "") return
        if (runLine(t)) { input.text = ""; return }
        if (world.chatBusy) return
        input.text = ""
        world.logAdd("me", t)
        send(t)
    }
    // a command or a shell line: runs here and is shown terminal-like;
    // false when it is something to say to the AI
    function runLine(t) {
        remember(t)
        if (t[0] === "!") {
            const cmd = t.slice(1).trim()
            if (cmd === "") return true
            const id = "sh" + Date.now()
            world.logAdd("shell", cmd, { aid: id, phase: "running", out: "" })
            runShell(id, cmd)
            return true
        }
        const res = commands ? commands.run(t) : null
        if (!res) return false
        if (!res.silent) world.logAdd("cmd", t, { phase: res.ok ? "done" : "failed", out: res.out })
        return true
    }
    function legendState() { return JSON.stringify({ actor: legend.actor, partner: legend.partner, level: legend.level, hint: legend.hint }) }
    function remember(t) {
        if (past[past.length - 1] !== t) past = past.concat([t]).slice(-100)
        pastAt = -1
    }
    function browse(step) {
        if (past.length === 0) return
        pastAt = Math.max(-1, Math.min(past.length - 1, pastAt + step))
        input.text = pastAt < 0 ? "" : past[past.length - 1 - pastAt]
        input.cursorPosition = input.text.length
    }
    // while you type he looks down at the input, then back
    function typing() {
        if (!seated) return
        st.gazeX = 0.7; st.gazeY = 0.8
        lookBack.restart()
    }
    Timer { id: lookBack; interval: 1400; onTriggered: { win.st.gazeX = 0; win.st.gazeY = 0 } }

    // ── the jump ─────────────────────────────────────────────────
    // jumpT 0: on the floor where he stands, 1: high above his corner;
    // drop 1: fallen into it
    property real jumpT: 0
    property real drop: 0
    readonly property real seatGX: card.x + header.seatX
    readonly property real seatGY: card.y + header.seatY
    readonly property real apexGY: Math.max(st.size + 8, seatGY - 120)
    property real fromX: 0
    property real bumpPop: 1
    // anything else that takes him out of the chat leaves no bump behind
    Connections {
        target: win.st
        function onPlaceChanged() {
            if (win.st.place === "chat" || win.away) return
            growAnim.stop(); shrinkAnim.stop()
            win.seated = false; win.growW = 0; win.growH = 0; win.contentIn = 0; win.drop = 0
        }
    }

    Connections {
        target: win.world
        function onChatHopOut(who) { if (who === win.st) win.hopOut() }
        function onChatJumpIn(who) {
            if (who !== win.st) return
            jumpOutAnim.stop(); shrinkAnim.stop(); collapseAnim.stop()
            if (win.seated) { growAnim.start(); return }
            win.fromX = who.x0
            win.jumpT = 0; win.drop = 0
            jumpInAnim.start()
        }
        function onChatJumpOut(who) {
            if (who !== win.st) return
            jumpInAnim.stop(); growAnim.stop()
            if (win.seated) { shrinkAnim.start(); return }
            if (win.jumpT < 0.01) { win.world.chatLeft(who); return }
            jumpOutAnim.start()
        }
    }
    SequentialAnimation {
        id: jumpInAnim
        // gathers himself, deep
        ScriptAction { script: { win.drop = 0; win.st.gazeY = -1 } }
        ParallelAnimation {
            NumberAnimation { target: win.st; property: "sx"; to: 1.3; duration: 170; easing.type: Easing.OutQuad }
            NumberAnimation { target: win.st; property: "sy"; to: 0.68; duration: 170; easing.type: Easing.OutQuad }
        }
        // a big leap, up past his corner
        ParallelAnimation {
            NumberAnimation { target: win; property: "jumpT"; to: 1; duration: 560; easing.type: Easing.OutQuad }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: win.st; property: "sx"; to: 0.8; duration: 130; easing.type: Easing.OutQuad }
                    NumberAnimation { target: win.st; property: "sy"; to: 1.28; duration: 130; easing.type: Easing.OutQuad }
                }
                ParallelAnimation {
                    NumberAnimation { target: win.st; property: "sx"; to: 1; duration: 320 }
                    NumberAnimation { target: win.st; property: "sy"; to: 1; duration: 320 }
                }
            }
            NumberAnimation { target: win.st; property: "rot"; from: 0; to: win.fromX > win.seatGX ? -360 : 360; duration: 560; easing.type: Easing.OutQuad }
        }
        ScriptAction { script: { win.st.rot = 0; win.st.gazeY = 0.6 } }
        // and down into it
        NumberAnimation { target: win; property: "drop"; to: 1; duration: 230; easing.type: Easing.InQuad }
        ParallelAnimation {
            NumberAnimation { target: win.st; property: "sx"; to: 1.32; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: win.st; property: "sy"; to: 0.72; duration: 70; easing.type: Easing.OutQuad }
        }
        // melts: the round bump takes his place and the card grows out of him
        ScriptAction { script: { win.st.sx = 1; win.st.sy = 1; win.st.gazeY = 0; win.bumpPop = 0.8; win.seated = true; win.away = false; growAnim.start() } }
    }
    SequentialAnimation {
        id: jumpOutAnim
        // out of the corner: a small hop up, then down to the floor
        ParallelAnimation {
            NumberAnimation { target: win.st; property: "sx"; to: 1.25; duration: 90 }
            NumberAnimation { target: win.st; property: "sy"; to: 0.78; duration: 90 }
        }
        ParallelAnimation {
            NumberAnimation { target: win; property: "drop"; to: 0; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: win.st; property: "sx"; to: 0.88; duration: 160 }
            NumberAnimation { target: win.st; property: "sy"; to: 1.15; duration: 160 }
        }
        ParallelAnimation {
            NumberAnimation { target: win; property: "jumpT"; to: 0; duration: 480; easing.type: Easing.InQuad }
            NumberAnimation { target: win.st; property: "sx"; to: 1; duration: 260 }
            NumberAnimation { target: win.st; property: "sy"; to: 1; duration: 260 }
        }
        ParallelAnimation {
            NumberAnimation { target: win.st; property: "sx"; to: 1.2; duration: 70 }
            NumberAnimation { target: win.st; property: "sy"; to: 0.8; duration: 70 }
        }
        ParallelAnimation {
            NumberAnimation { target: win.st; property: "sx"; to: 1; duration: 200; easing.type: Easing.OutBack }
            NumberAnimation { target: win.st; property: "sy"; to: 1; duration: 200; easing.type: Easing.OutBack }
        }
        ScriptAction { script: { win.st.x0 = win.fromX; win.world.chatLeft(win.st) } }
    }
    SequentialAnimation {
        id: boingAnim
        NumberAnimation { target: win; property: "bumpPop"; to: 1.14; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: win; property: "bumpPop"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }

    // ── him, on the way, and as the bump ─────────────────────────
    readonly property real figX: fromX + (seatGX - fromX) * jumpT
    readonly property real figY: mixed(floor, apexGY, jumpT) + (seatGY - apexGY) * drop
    readonly property bool figOn: st.place === "chat" && !seated

    // the floor clips him while he rises out of it; the card does not
    Item {
        width: parent.width
        height: win.floor
        clip: true
        Creature {
            st: win.st
            visible: win.figOn
            x: win.figX
            y: win.figY
        }
    }
    Item {
        id: figGlass
        readonly property bool on: win.figOn && win.st.skin === "kuro" && win.st.sink < 0.95
        width: on ? win.st.size * win.st.sx : 0
        height: on ? win.st.size * win.st.sy : 0
        x: win.figX - width / 2
        y: win.figY - height - win.st.lift + win.st.sink * (win.st.size + 14)
    }
    // his face in the bump
    Item {
        visible: win.seated
        x: win.bumpCX + win.bumpR * 0.06
        y: win.bumpCY + win.bumpR * 0.08
        scale: win.bumpPop
        readonly property bool cake: win.st.cakeFace
        readonly property color ink: win.world.inkFor(win.world.bubbleBg)
        Rectangle {
            visible: win.st.skin === "robo"
            width: win.st.size * 0.62; height: win.st.size * 0.34
            radius: height * 0.4
            x: -width / 2; y: -height / 2
            color: "#1d2128"
        }
        LongEyes {
            visible: !parent.cake
            st: win.st
            ink: win.st.skin === "robo" ? win.world.primary : parent.ink
        }
        Face {
            visible: parent.cake
            st: win.st
            ink: parent.ink
            scale: 0.9
        }
    }
    Item {
        id: figHit
        readonly property bool on: win.seated
        width: on ? win.bumpR * 2 : 0
        height: on ? win.bumpR * 2 : 0
        x: win.bumpCX - win.bumpR
        y: win.bumpCY - win.bumpR
        // a click: a little boing; dragged: out of the window by the pointer,
        // the window stays open (as from the frame)
        MouseArea {
            id: seatMa
            anchors.fill: parent
            preventStealing: true
            property bool dragged: false
            property point pressAt: Qt.point(0, 0)
            cursorShape: dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onPressed: m => { dragged = false; const p = mapToItem(null, m.x, m.y); pressAt = Qt.point(p.x, p.y) }
            onPositionChanged: m => {
                const p = mapToItem(null, m.x, m.y)
                if (!dragged && Math.hypot(p.x - pressAt.x, p.y - pressAt.y) > 8) {
                    dragged = true
                    win.pulledOut()
                    win.brain.grab(pressAt.x, pressAt.y)
                }
                if (dragged) win.brain.drag(p.x, p.y)
            }
            onReleased: if (dragged) win.brain.release()
            onCanceled: if (dragged) win.brain.release()
            onClicked: if (!dragged) { boingAnim.restart(); win.st.mood = "happy" }
        }
    }
}
