import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.theme
import qs.services
import qs.pages

Rectangle {
    id: root

    property bool expanded: false
    property bool classic: false         // classic bar: when closed it is a pill [wifi ⚙ bluetooth]
    property string page: "main"        // main | tools | monitors | wifi | bluetooth | display | sound

    // The three main pages: switch with the dots, the wheel or Alt+1/2/3
    readonly property var pager: ["main", "tools", "monitors"]
    readonly property int pageIndex: pager.indexOf(page)
    readonly property bool inPager: pageIndex >= 0

    function close() { expanded = false }

    function gotoPage(i) {
        if (i < 0 || i >= pager.length) return
        page = pager[i]
    }

    readonly property bool hovered: hover.hovered
    readonly property bool btOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property bool needsKeyboard: expanded && page === "wifi" && wifiPage.needsKeyboard
    readonly property bool busy: mainPage.dragging || displayPage.dragging || soundPage.dragging
                                 || toolsPage.dragging || monitorsPage.dragging || needsKeyboard

    readonly property int cardW: 360
    readonly property int headerH: 34                           // strip with the page dots
    readonly property int baseMainH: Battery.present ? 510 : 454
    readonly property int mainH: baseMainH + headerH
    readonly property int cardH: page === "main" ? mainH : (page === "tools" ? 536 : 440)

    width:  expanded ? cardW : (classic ? 104 : Theme.islandHeight)
    height: expanded ? cardH : Theme.islandHeight
    radius: Math.min(26, height / 2)
    color: (!expanded && hovered) ? Theme.islandHover : Theme.island
    border.width: 1
    border.color: Theme.border
    clip: true

    Behavior on width  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on color  { ColorAnimation { duration: 120 } }

    onExpandedChanged: {
        UiState.controlOpen = expanded
        if (expanded) {
            resetTimer.stop()
            Brightness.refresh()
            NotifCenter.unread = false
        } else {
            resetTimer.restart()      // back to the main page once the card is closed
        }
    }

    Timer {
        id: resetTimer
        interval: 350
        onTriggered: root.page = "main"
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop()
                root.expanded = true
            } else {
                collapseTimer.restart()
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 300
        onTriggered: {
            if (root.busy) restart()      // don't close while dragging or typing
            else root.expanded = false
        }
    }

    // Wheel: switches between pages
    // (over scrollable lists the wheel scrolls the list)
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!root.expanded || wheelCool.running || !root.inPager) return
            const next = root.pageIndex + (event.angleDelta.y < 0 ? 1 : -1)
            if (next < 0 || next >= root.pager.length) return
            root.gotoPage(next)
            wheelCool.start()
        }
    }

    Timer {
        id: wheelCool
        interval: 450
    }

    // ---------- Closed state: wifi + battery ring ----------
    Glyph {
        x: (Theme.islandHeight - width) / 2
        y: (Theme.islandHeight - height) / 2
        kind: "wifi"
        level: Network.level
        size: 16
        color: Network.wifiOn ? (Network.connected ? Theme.accent : Theme.foreground) : Theme.muted

        opacity: (root.expanded || root.classic) ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Canvas {
        id: ring

        width: Theme.islandHeight
        height: Theme.islandHeight
        opacity: (root.expanded || root.classic) ? 0 : 1
        visible: Battery.present && opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        property real pct: Battery.percent
        property color tone: Battery.tone

        onPctChanged: requestPaint()
        onToneChanged: requestPaint()
        onVisibleChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = width / 2
            const r = c - 2.5
            const start = -Math.PI / 2

            ctx.lineWidth = 2.2
            ctx.lineCap = "round"

            ctx.strokeStyle = Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
            ctx.beginPath()
            ctx.arc(c, c, r, 0, Math.PI * 2)
            ctx.stroke()

            if (pct > 0.005) {
                ctx.strokeStyle = tone
                ctx.beginPath()
                ctx.arc(c, c, r, start, start + Math.PI * 2 * Math.min(1, pct))
                ctx.stroke()
            }
        }
    }

    Rectangle {
        x: Theme.islandHeight - 9
        y: 2
        width: 7
        height: 7
        radius: 3.5
        color: Theme.accent
        visible: NotifCenter.unread && !root.expanded && !root.classic
    }

    // ---------- Classic bar, when closed: wifi · settings · bluetooth ----------
    Row {
        anchors.centerIn: parent
        spacing: 14
        opacity: (root.classic && !root.expanded) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Glyph {
            kind: "wifi"
            level: Network.level
            size: 15
            color: Network.wifiOn ? (Network.connected ? Theme.accent : Theme.foreground) : Theme.muted
        }

        Glyph {
            kind: "gear"
            size: 15
            color: Theme.foreground
        }

        Glyph {
            kind: "bluetooth"
            size: 15
            color: (root.btOn) ? Theme.accent : Theme.muted
        }
    }

    // ---------- Top strip: page dots (click or Alt+1/2/3) ----------
    // Small ones, the current page's dot stretches
    Item {
        id: dotsStrip
        z: 50
        x: 0; y: 0
        width: root.cardW
        height: root.headerH
        opacity: (root.expanded && root.inPager) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            spacing: 5

            Repeater {
                model: root.pager.length

                delegate: Rectangle {
                    id: dot

                    required property int index

                    width: root.pageIndex === index ? 16 : 5
                    height: 5
                    radius: 2.5
                    color: root.pageIndex === index ? Theme.accent : Theme.mix(Theme.island, Theme.foreground, 0.30)
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.gotoPage(dot.index)
                    }
                }
            }
        }
    }

    // ---------- Pages (cross-fade) ----------
    MainPage {
        id: mainPage
        y: root.headerH
        height: root.baseMainH
        opacity: (root.expanded && root.page === "main") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onOpenPage: name => root.page = name
        onPowerRequested: { root.expanded = false; Power.open() }
    }

    ToolsPage {
        id: toolsPage
        y: -10
        opacity: (root.expanded && root.page === "tools") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "main"
        onPasted: root.expanded = false
    }

    MonitorsPage {
        id: monitorsPage
        y: root.headerH
        height: root.cardH - root.headerH
        opacity: (root.expanded && root.page === "monitors") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onOpenPage: name => root.page = name
    }

    WifiPage {
        id: wifiPage
        opacity: (root.expanded && root.page === "wifi") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "main"
    }

    BluetoothPage {
        id: btPage
        opacity: (root.expanded && root.page === "bluetooth") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "main"
    }

    DisplayPage {
        id: displayPage
        opacity: (root.expanded && root.page === "display") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "main"
    }

    SoundPage {
        id: soundPage
        opacity: (root.expanded && root.page === "sound") ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.page = "main"
    }
}
