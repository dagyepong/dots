import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common.widgets

// The notification popups: a stack of cards in the top-right corner, newest
// on top, that arrive when a notification does and go away by themselves.
// (Settings > General > "Notification alert": "Popups" is this, "Phone" is
// the default alert where the Quick Panel's phone rises and buzzes instead.)
//
// What is on the stack, and for how long, is NotificationSource.qml's
// (`popups`, closePopup / dismiss / holdPopup): this file only draws it and
// reports what you do to a card. The cards' ListModel is kept in step with
// source.popups by sync(): a popup that appears is inserted at the top, one
// that is gone is marked `leaving`, so its card can slide out first and
// then be dropped (drop(), when the card says finished()).
//
// Where: like the reload report (ReloadPopup.qml): top-right, clear of the
// bar (a top bar pushes it down, a right bar pushes it left); with the bar
// at the bottom it goes to the bottom-right corner, above the bar, and the
// stack grows upward. One persistent window per screen, but only the
// monitor that was focused when the stack started to fill (source.popupMonitor)
// shows it. The window is as tall as maxPopups cards; only the cards
// themselves take the pointer (the mask), the rest of it lets clicks through.
//
// Hidden while the phone is up (source.popupsSuppressed): its list already
// shows everything. Drawn in design pixels inside a ScaleHost, like the OSD,
// so it follows the monitor's scale (scale.json).
Variants {
    id: root

    // NotificationSource.qml; shell.qml hands it over.
    property var source: null

    // The card is drawn at its design size (cardW x cardH) and the whole
    // stack is then shrunk by this (1 = the old size).
    readonly property real compact: 0.78
    readonly property real cardW: 420
    readonly property real cardH: 104
    readonly property real shadowX: 5
    readonly property real shadowY: 4
    readonly property real cardGap: 12      // between cards
    readonly property int gap: 14           // from the bar
    readonly property int maxCards: root.source ? root.source.maxPopups : 4

    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        readonly property real uiScale: ShellScale.forScreen(win.screen)
        readonly property real cardScale: win.uiScale * root.compact
        readonly property string barPosition: BarPositionService.position
        readonly property bool atBottom: win.barPosition === "bottom"
        readonly property real barOffset: Math.round((BarPositionService.thickness + root.gap) * win.uiScale)
        readonly property real edgeGap: Math.round(16 * win.uiScale)

        readonly property bool shown: root.source !== null
            && win.modelData.name === root.source.popupMonitor
            && !root.source.popupsSuppressed
            && notices.count > 0

        visible: win.shown
        color: "transparent"
        // Doesn't reserve screen space.
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "sekaipop-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: !win.atBottom
            bottom: win.atBottom
            right: true
        }
        margins {
            top: win.barPosition === "top" ? win.barOffset : win.edgeGap
            bottom: win.atBottom ? win.barOffset : 0
            right: win.barPosition === "right" ? win.barOffset : win.edgeGap
        }

        implicitWidth: Math.ceil((root.cardW + root.shadowX) * win.cardScale)
        implicitHeight: Math.ceil((root.maxCards * (root.cardH + root.shadowY) + (root.maxCards - 1) * root.cardGap) * win.cardScale)

        // Only the cards take the pointer, in real window pixels (the cards
        // are drawn scaled by uiScale). Nothing showing: 1 px in the corner.
        mask: Region { item: hitArea }
        Item {
            id: hitArea
            readonly property real used: Math.ceil(list.contentHeight * win.cardScale)
            x: 0
            y: win.atBottom ? win.height - height : 0
            width: win.width
            height: win.shown ? Math.max(1, Math.min(win.height, hitArea.used)) : 1
        }

        // ===== the stack =====
        ListModel { id: notices }

        function indexOfKey(key) {
            for (let i = 0; i < notices.count; i++) {
                if (notices.get(i).key === key)
                    return i
            }
            return -1
        }

        // The card has slid out: take it off the stack.
        function drop(key) {
            const i = win.indexOfKey(key)
            if (i >= 0)
                notices.remove(i)
        }

        // Bring the cards in step with source.popups (newest first).
        function sync() {
            const list = root.source ? root.source.popups : []
            const wanted = {}
            for (let i = 0; i < list.length; i++)
                wanted[list[i].key] = true

            for (let i = 0; i < notices.count; i++) {
                const item = notices.get(i)
                if (!wanted[item.key] && !item.leaving)
                    notices.setProperty(i, "leaving", true)
            }

            // Oldest of the new ones first, each inserted on top, so the
            // newest ends up on top.
            for (let j = list.length - 1; j >= 0; j--) {
                const e = list[j]
                if (win.indexOfKey(e.key) >= 0)
                    continue
                notices.insert(0, {
                    key: e.key,
                    app: e.app,
                    title: e.title,
                    body: e.body,
                    urgency: e.urgency,
                    icon: e.icon,
                    leaving: false
                })
            }
        }

        Connections {
            target: root.source
            function onPopupsChanged() {
                win.sync()
            }
        }

        Component.onCompleted: win.sync()

        ScaleHost {
            anchors.fill: parent
            factor: win.cardScale

            ListView {
                id: list
                anchors.fill: parent
                interactive: false
                model: notices
                spacing: root.cardGap
                verticalLayoutDirection: win.atBottom ? ListView.BottomToTop : ListView.TopToBottom

                delegate: NotificationPopupCard {
                    cardWidth: root.cardW
                    cardHeight: root.cardH

                    onClosed: {
                        if (root.source)
                            root.source.closePopup(key)
                    }
                    // A click: the app's own action when it has one (that also removes
                    // the notification); otherwise it just hides the popup, as before.
                    onActivated: {
                        if (root.source && !root.source.activate(key))
                            root.source.closePopup(key)
                    }
                    onDismissed: {
                        if (root.source)
                            root.source.dismiss(key)
                    }
                    onHoverToggled: hovering => {
                        if (root.source)
                            root.source.holdPopup(key, hovering)
                    }
                    onFinished: win.drop(key)
                }

                // The ones below (or above, with the bar at the bottom) move
                // over when a card arrives or leaves.
                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
