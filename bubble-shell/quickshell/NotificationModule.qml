pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Shapes

ShellRoot {
    id: root

    enum Mode { Idle, Compact, Big }

    // Two separate Wayland surfaces: a combined surface suppressed Hyprland
    // blur in the region where the two pills overlapped.
    readonly property bool _active: centerOpen || _isExpanded

    readonly property int unreadCount: notifCount

    // Currently-shown toast derives from notifServer.trackedNotifications
    // (single source of truth — never assign currentToast directly).
    readonly property var _newestTracked: {
        const xs = notifs
        return xs && xs.length > 0 ? xs[xs.length - 1] : null
    }
    // Visually hidden (auto-expired or arrived while center was open) but
    // still tracked. Cleared when a newer notification arrives.
    property var _autoHiddenToast: null
    readonly property var currentToast:
        !centerOpen
            && _newestTracked !== null
            && _newestTracked !== _autoHiddenToast
        ? _newestTracked : null
    readonly property bool hasToast: currentToast !== null

    property bool centerOpen: false

    // Persists across dismiss so hover-peek can re-show the last toast.
    property string _lastAppName: ""
    property string _lastSummary: ""
    property string _lastBody: ""
    property string _lastIcon: ""
    property string _lastTime: ""

    // centerOpen is orthogonal to mode: it overrides pill width/height via
    // activeWidth/Height regardless of which mode is active.
    property int mode: NotificationModule.Mode.Idle

    readonly property int emptyPillWidth: 40
    readonly property int pillBottomMargin: 8
    readonly property int leftEdgePad: 8
    readonly property int currentPillWidth: pill ? pill.implicitWidth : emptyPillWidth
    // Workspace panel anchors to this so it stays clear of the critical bigPill.
    readonly property int currentPillRightEdge: {
        const mainRight = leftEdgePad + currentPillWidth
        // bigPill rests invisibly at toastSub dimensions when not critical,
        // so only count its width while it's actually visually present.
        const bigVisible = bigPill && (_isBig || bigPill.height > 25)
        const bigRight = bigVisible ? (bigPill.x + bigPill.implicitWidth) : 0
        return Math.max(mainRight, bigRight)
    }

    readonly property int bigPillFullWidth: 276
    readonly property int bigPillHeight: 54
    readonly property int compactPillHeight: 36

    // Notification center (expanded pill) constants.
    readonly property int centerWidth: 302
    readonly property int centerCornerRadius: 16
    readonly property int centerTopPad: 16
    readonly property int centerSidePad: 16
    readonly property int centerBottomPad: 8
    readonly property int centerHeaderHeight: 26
    readonly property int centerGapAboveLine: 12
    readonly property int centerGapBelowLine: 12

    readonly property var notifs: notifServer && notifServer.trackedNotifications
        ? notifServer.trackedNotifications.values
        : []

    // notif.id → ms epoch, populated in onNotification.
    property var receivedAt: ({})

    readonly property color fgPrimary:   Qt.rgba(1, 1, 1, 0.8)
    readonly property color fgSecondary: Qt.rgba(1, 1, 1, 0.5)
    readonly property color fgTertiary:  Qt.rgba(1, 1, 1, 0.3)
    readonly property color bgSubtle:    Qt.rgba(1, 1, 1, 0.10)
    readonly property color bgHover:     Qt.rgba(1, 1, 1, 0.18)
    readonly property color noColor:     Qt.rgba(0, 0, 0, 0)

    // Reactive notification count — bound to the Repeater deep inside the
    // center body. Repeater.count updates on model add/remove; using this
    // avoids the snapshot-nature of `trackedNotifications.values`.
    readonly property int notifCount: notifList ? notifList.count : 0

    // Cap so the expanded pill fits inside mainPanel's fixed 500-tall surface
    // (chrome ~75 + bottomMargin ~7 + X overhang ~3 + body ≤ 400).
    readonly property int maxCenterBodyHeight: 400

    // Per-item height (76 = 2-line body at 40 + 36 chrome) is ESTIMATED, not
    // measured, to avoid a binding loop between centerBody.height and its
    // Flickable child's contentHeight. Keep in sync with the delegate.
    readonly property int centerBodyHeight: notifCount === 0
        ? 152
        : Math.min(maxCenterBodyHeight, notifCount * 76)
    readonly property int centerHeight: centerTopPad + centerHeaderHeight + centerGapAboveLine
        + 1 + centerGapBelowLine + centerBodyHeight + centerBottomPad

    // Reusable X button (used by the compact-toast overlay AND each notification
    // item in the expanded center). Always 18×18, rounded-9, with an x.svg glyph.
    // Callers supply the `baseAlpha` (rest color) and wire `onClicked`.
    component XButton: Rectangle {
        id: xBtn
        signal clicked()
        property real baseAlpha: 0.15
        property real hotAlpha:  0.35
        readonly property alias hovered: _xMouse.containsMouse

        width: 18
        height: 18
        radius: 9
        color: _xMouse.containsMouse
            ? Qt.rgba(1, 1, 1, hotAlpha)
            : Qt.rgba(1, 1, 1, baseAlpha)
        Behavior on color { ColorAnimation { duration: 150 } }

        Image {
            anchors.centerIn: parent
            width: 12
            height: 12
            source: Qt.resolvedUrl("x.svg")
            sourceSize: Qt.size(24, 24)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        MouseArea {
            id: _xMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: xBtn.clicked()
        }
    }

    // Hover-peek: when idle and any part of the pill (bell, toast card, or
    // the X overlay) is hovered, show the cached toast in compact form.
    // Each inner MouseArea steals hover in its own region, so we OR them all
    // together — missing any one creates dead zones where peek dies mid-move.
    // Requires at least one live notification; cached `_lastBody` alone is
    // not enough, else peek resurrects content the user already dismissed.
    readonly property bool _peekable: mode === NotificationModule.Mode.Idle
        && notifCount > 0
        && (bellHover.containsMouse
            || bellClick.containsMouse
            || toastInvoke.containsMouse
            || toastX.hovered)
        && (_lastSummary !== "" || _lastBody !== "")
    readonly property bool _isExpanded: mode !== NotificationModule.Mode.Idle || _peekable
    readonly property bool _isBig: mode === NotificationModule.Mode.Big

    // Sole state-transition handler for mode/timers/caches. Everything else
    // flows through this via the derived currentToast binding.
    onCurrentToastChanged: {
        criticalCompactTimer.stop()
        criticalBigTimer.stop()
        if (currentToast) {
            _lastAppName = currentToast.appName || "Notification"
            _lastSummary = currentToast.summary || ""
            _lastBody    = currentToast.body || ""
            _lastIcon    = currentToast.image || currentToast.appIcon || ""
            _lastTime    = Qt.formatTime(new Date(), "h:mmap").toLowerCase()
            mode = NotificationModule.Mode.Compact
            // Sender's expireTimeout is ignored: apps commonly pass 0 / -1
            // ("never" / "server default") but the shell always reclaims room.
            toastLifeTimer.interval =
                currentToast.urgency === NotificationUrgency.Critical ? 60000
                : currentToast.urgency === NotificationUrgency.Low ? 2500
                : 5000
            toastLifeTimer.restart()
            if (currentToast.urgency === NotificationUrgency.Critical) {
                criticalCompactTimer.restart()
            }
        } else {
            mode = NotificationModule.Mode.Idle
            toastLifeTimer.stop()
        }
    }

    // On center close, mark the newest as "already seen" so it doesn't
    // resurface as a toast. New arrivals clear this marker again.
    onCenterOpenChanged: {
        if (!centerOpen) _autoHiddenToast = _newestTracked
    }

    NotificationServer {
        id: notifServer
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: (notif) => {
            notif.tracked = true

            const next = Object.assign({}, root.receivedAt)
            next[notif.id] = Date.now()
            root.receivedAt = next

            // Cleared so the new notification surfaces as a toast (all other
            // state is driven by the currentToast binding).
            root._autoHiddenToast = null
        }
    }

    // Critical-urgency choreography: 350ms compact → big → 5s → compact.
    Timer {
        id: criticalCompactTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.mode = NotificationModule.Mode.Big
            criticalBigTimer.restart()
        }
    }
    Timer {
        id: criticalBigTimer
        interval: 5000
        repeat: false
        onTriggered: root.mode = NotificationModule.Mode.Compact
    }

    Timer {
        id: toastLifeTimer
        interval: 5000
        repeat: false
        // Auto-expiry only hides the toast; user-initiated X/Clear is the
        // only path that actually calls dismiss() on the Notification.
        onTriggered: root.hideActiveToast()
    }

    // Called from every dismiss path so receivedAt doesn't grow unbounded.
    function _forgetReceivedAt(id) {
        if (id === undefined || !(id in receivedAt)) return
        const next = Object.assign({}, receivedAt)
        delete next[id]
        receivedAt = next
    }

    function dismissToast() {
        const t = currentToast
        if (!t) return
        const id = t.id
        t.dismiss()
        _forgetReceivedAt(id)
    }

    // Called by the auto-expire timer — hides the visible toast without
    // dismissing the underlying Notification, so it stays in the center's
    // list for later review. The marker points at the current newest; the
    // derivation then yields null until either a new notification arrives
    // (which clears the marker in onNotification) or this one is dismissed
    // via the center.
    function hideActiveToast() {
        _autoHiddenToast = _newestTracked
    }

    // Invoke the notification's default action (what the spec calls "default")
    // — this is what opens Slack at the message, Claude Code at the terminal,
    // etc. Falls back to the first action if no explicit default is declared.
    // Always dismisses the toast afterwards so the pill returns to idle.
    function invokeActiveToast() {
        const t = currentToast
        if (!t) { dismissToast(); return }
        const actions = t.actions
        if (actions && actions.length > 0) {
            for (let i = 0; i < actions.length; i++) {
                if (actions[i].identifier === "default") {
                    actions[i].invoke()
                    dismissToast()
                    return
                }
            }
            actions[0].invoke()
        }
        dismissToast()
    }

    function clearAllNotifs() {
        const list = notifs.slice()
        for (let i = 0; i < list.length; i++) {
            const n = list[i]
            if (!n) continue
            const id = n.id
            n.dismiss()
            _forgetReceivedAt(id)
        }
    }

    function _formatTime(ms) {
        if (!ms) return ""
        const d = new Date(ms)
        const h = d.getHours() % 12 || 12
        const mm = d.getMinutes().toString().padStart(2, '0')
        const ap = d.getHours() >= 12 ? "pm" : "am"
        return h + ":" + mm + ap
    }

    // Dismiss the expanded center when the user clicks outside either pill.
    HyprlandFocusGrab {
        active: root.centerOpen
        windows: [mainPanel, bigPanel]
        onCleared: root.centerOpen = false
    }

    PanelWindow {
        id: mainPanel

        anchors.bottom: true
        anchors.left: true
        margins.bottom: 0
        margins.left: 0
        // Fixed surface size: the pill animates inside a static canvas so
        // Hyprland never resizes the layer shell. Resizing triggered a frame
        // race that teleported the bell at the end of close animations.
        implicitWidth: 800
        implicitHeight: 500
        color: "transparent"

        // bigPanel stays at Overlay; splitting layers guarantees it renders
        // above this one instead of z-fighting within a single layer.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-clock"
        exclusionMode: ExclusionMode.Ignore

        // Only the pill and X button capture input — the rest of the
        // transparent surface falls through to adjacent panels.
        mask: Region {
            item: pill
            Region { item: toastX }
        }

        // FocusGrab alone doesn't fire for clicks that land on this window's
        // own transparent region, so we need an explicit catcher.
        MouseArea {
            anchors.fill: parent
            enabled: root.centerOpen
            z: -100
            onClicked: root.centerOpen = false
        }

    Pill {
        id: pill
        x: root.leftEdgePad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pillBottomMargin
        // Parent pill stays compact-height always; critical toasts extract
        // their content into a separate bigPill so the bell never shifts.
        pillHeight: root.compactPillHeight
        interactive: false

        activeWidth:        root.centerOpen ? root.centerWidth : -1
        activeHeight:       root.centerOpen ? root.centerHeight : -1
        activeCornerRadius: root.centerOpen ? root.centerCornerRadius : -1

        // Bell sub-pill hover affordance; never auto-activated by toast arrival.
        readonly property bool chipMode: bellClick.containsMouse

        readonly property int bellSubWidth: root.unreadCount > 0
            ? (4 + 20 + 4 + unreadText.implicitWidth + 8)
            : (4 + 20 + 4)
        readonly property int toastTextMax: 220
        // TextMetrics (not Text.implicitWidth): elided anchored Text would
        // binding-loop against bubble width and lock in an under-sized first
        // pass, permanently eliding toasts that should have fit.
        readonly property int toastSubWidth: 4
            + (toastIcon.visible ? (16 + 4) : 0)
            + Math.min(toastTextMetrics.advanceWidth, toastTextMax)
            + (toastInvoke.containsMouse ? 12 : 4)

        collapsedWidth: {
            // Keep toast-reserved width during Big so parent doesn't shrink
            // when the toast sub-pill hides.
            if (root._isExpanded) return 4 + bellSubWidth + toastSubWidth + 6
            if (chipMode) {
                return root.unreadCount > 0
                    ? (4 + bellSubWidth + 6)
                    : (6 + bellSubWidth + 6)
            }
            return 10 + 20 + (root.unreadCount > 0 ? 4 + unreadText.implicitWidth : 0) + 10
        }
        expandedWidth: collapsedWidth

        Rectangle {
            id: bellSubBg
            visible: !root.centerOpen
            x: root._isExpanded ? 4 : (root.unreadCount > 0 ? 4 : 6)
            y: (pill.height - height) / 2
            width: pill.bellSubWidth
            height: 28
            radius: 14
            color: pill.chipMode ? root.bgSubtle : root.noColor
            Behavior on color { ColorAnimation  { duration: 200 } }
            Behavior on x     { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        readonly property int _bellX: {
            if (root.centerOpen) return root.centerSidePad
            if (root._isExpanded) return 8
            if (pill.chipMode && root.unreadCount > 0) return 8
            return 10
        }
        readonly property int _bellY: root.centerOpen
            ? root.centerTopPad
            : (root.compactPillHeight - 20) / 2

        Image {
            id: bellGlyph
            x: pill._bellX
            y: pill._bellY
            width: 20; height: 20
            source: Qt.resolvedUrl("bell.svg")
            sourceSize: Qt.size(40, 40)
            fillMode: Image.PreserveAspectFit
            smooth: true
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        Text {
            id: unreadText
            visible: root.centerOpen || root.unreadCount > 0
            x: bellGlyph.x + 20 + 4
            anchors.verticalCenter: bellGlyph.verticalCenter
            text: root.centerOpen
                ? (root.notifCount + " Notifications")
                : root.unreadCount.toString()
            color: root.fgPrimary
            font.family: "Geist"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: -0.12
        }

        Rectangle {
            id: toastSub
            visible: !root._isBig && !root.centerOpen && root._isExpanded
            x: 4 + pill.bellSubWidth
            y: (pill.height - height) / 2
            width: pill.toastSubWidth
            height: 24
            radius: 12
            // Uses the dedicated toastInvoke MouseArea: bellHover covers the
            // same area and would otherwise shadow this rectangle's hover.
            color: toastInvoke.containsMouse ? root.bgSubtle : root.noColor
            Behavior on color { ColorAnimation { duration: 200 } }

            Image {
                id: toastIcon
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                source: root._lastIcon
                visible: source != ""
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Text {
                id: toastText
                anchors.left: toastIcon.visible ? toastIcon.right : parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                // Explicit width from TextMetrics, NOT anchors.right. Anchoring
                // both sides created a feedback loop (bubble.width ↔ text.width)
                // where the text would settle at a clamped value before the
                // metrics propagated, eliding short text that should have fit.
                // No Behavior: if width animates between values, the text
                // briefly has less room than its glyphs need and elides mid-
                // animation, causing a visible `"...→full→..."` flash. Snap
                // instantly instead — the outer pill still animates via its
                // own implicitWidth Behavior, hiding the width-jump here.
                width: Math.min(toastTextMetrics.advanceWidth, pill.toastTextMax)
                // Compact/peek shows the summary (short glance line). Fall
                // back to body for notifications that only send a body.
                text: root._lastSummary !== "" ? root._lastSummary : root._lastBody
                color: toastInvoke.containsMouse ? root.fgPrimary : Qt.rgba(1, 1, 1, 0.7)
                Behavior on color { ColorAnimation { duration: 200 } }
                font.family: "Geist"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: -0.12
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Mirrors toastText's font + content and exposes the TRUE natural
            // width (advanceWidth). Used by toastSubWidth to break the binding
            // loop caused by Text.implicitWidth getting clamped when the Text
            // element is anchors-bound with elide + maximumLineCount.
            TextMetrics {
                id: toastTextMetrics
                text: toastText.text
                font: toastText.font
            }
        }

        // Full-pill hover detector — drives peek/chip-mode reveal. Click here
        // only OPENS the center; empty-pill clicks inside the expanded state
        // do nothing (so the user doesn't dismiss by clicking near an item).
        MouseArea {
            id: bellHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: if (!root.centerOpen) root.centerOpen = true
        }

        // Dedicated bell-glyph click target — declared AFTER bellHover so it
        // takes priority in the bell region. Toggles the center (opens when
        // closed, closes when open), giving the user a single predictable
        // control to flip the expanded view.
        MouseArea {
            id: bellClick
            x: pill._bellX - 4
            y: pill._bellY - 4
            width: 28
            height: 28
            hoverEnabled: true  // drives chipMode — bell-only hover state
            acceptedButtons: Qt.LeftButton
            onClicked: root.centerOpen = !root.centerOpen
        }

        // Declared after bellHover/bellClick so it wins hover/clicks on the
        // toast region.
        MouseArea {
            id: toastInvoke
            x: toastSub.x
            y: toastSub.y
            width: toastSub.width
            height: toastSub.height
            visible: toastSub.visible
            enabled: toastSub.visible
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: root.invokeActiveToast()
        }

        Rectangle {
            id: clearBtn
            visible: root.centerOpen && root.notifCount > 0
            x: root.centerWidth - 45 - root.centerSidePad
            y: root.centerTopPad
            width: 45
            height: root.centerHeaderHeight
            radius: 13
            color: clearMouse.containsMouse ? root.bgHover : root.bgSubtle
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "Clear"
                color: root.fgPrimary
                font.family: "Geist"
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: -0.1
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.clearAllNotifs()
            }
        }

        Rectangle {
            id: centerSeparator
            visible: root.centerOpen
            x: root.centerSidePad
            y: root.centerTopPad + root.centerHeaderHeight + root.centerGapAboveLine
            width: root.centerWidth - 2 * root.centerSidePad
            height: 1
            color: root.bgSubtle
        }

        Item {
            id: centerBody
            visible: root.centerOpen
            x: root.centerSidePad
            y: centerSeparator.y + 1 + root.centerGapBelowLine
            width: root.centerWidth - 2 * root.centerSidePad
            height: root.centerBodyHeight

            Text {
                visible: root.notifCount === 0
                anchors.centerIn: parent
                text: "No notifications"
                color: root.fgTertiary
                font.family: "Geist"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            // Flickable+Column+Repeater instead of ListView: Column auto-sizes
            // to actual delegate heights, avoiding ListView's fixed-slot padding
            // when one item is shorter than expected.
            Flickable {
                id: notifList
                visible: root.notifCount > 0
                x: -8
                width: 286
                height: parent.height
                clip: true
                contentHeight: notifCol.height
                boundsBehavior: Flickable.StopAtBounds

                readonly property alias count: notifRepeater.count

                Column {
                    id: notifCol
                    width: 286

                    Repeater {
                        id: notifRepeater
                        // Reversed for newest-first display order.
                        model: {
                            const arr = root.notifs
                            return arr ? arr.slice().reverse() : []
                        }

                        delegate: Rectangle {
                        id: item
                        required property var modelData
                        required property int index

                        readonly property string _body: modelData ? (modelData.body || modelData.summary || "") : ""
                        readonly property string _app: modelData ? (modelData.appName || "Notification") : ""
                        readonly property string _icon: modelData ? (modelData.image || modelData.appIcon || "") : ""
                        readonly property real _ts: (modelData && root.receivedAt)
                            ? (root.receivedAt[modelData.id] || 0)
                            : 0

                        width: 286
                        height: itemBody.contentHeight + 36  // 8 top + 16 header + 4 gap + 8 bot
                        radius: 12
                        color: itemHover.containsMouse ? root.bgSubtle : root.noColor
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: itemHover
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        XButton {
                            id: itemX
                            visible: itemHover.containsMouse || hovered
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.top: parent.top
                            anchors.topMargin: -3
                            onClicked: {
                                if (!item.modelData) return
                                const id = item.modelData.id
                                item.modelData.dismiss()
                                root._forgetReceivedAt(id)
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 8

                            Item {
                                id: itemHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 16

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    // QML warns when Row children anchor themselves,
                                    // so use Row's built-in cross-axis alignment.
                                    Image {
                                        width: 16; height: 16
                                        source: item._icon
                                        visible: source != ""
                                        sourceSize: Qt.size(32, 32)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }
                                    Text {
                                        text: item._app
                                        color: root.fgSecondary
                                        font.family: "Geist"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root._formatTime(item._ts)
                                    color: root.fgSecondary
                                    font.family: "Geist"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }

                            Text {
                                id: itemBody
                                anchors.top: itemHeader.bottom
                                anchors.topMargin: 4
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: item._body
                                color: root.fgPrimary
                                font.family: "Geist"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                lineHeight: 20
                                lineHeightMode: Text.FixedHeight
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                        }
                    }
                }
            }
        }
        }

        // Sibling of pill (same parent) so anchors resolve. Big-mode X lives
        // in bigPanel.
        XButton {
            id: toastX
            // Show only when the cursor is over the toast card (or the X
            // itself) — hovering elsewhere on the pill (e.g. the bell) no
            // longer reveals the X, matching the Figma's hover behavior.
            visible: !root.centerOpen && !root._isBig && root._isExpanded
                && (toastInvoke.containsMouse || hovered)
            anchors.right: pill.right
            anchors.rightMargin: 5
            anchors.top: pill.top
            anchors.topMargin: -3
            baseAlpha: 0.15
            onClicked: root.dismissToast()
        }
    }

    // Separate layer surface so Hyprland blur doesn't lose the overlap
    // region (a combined surface suppressed blur where the two pills met).
    PanelWindow {
        id: bigPanel

        anchors.bottom: true
        anchors.left: true
        margins.bottom: 0
        margins.left: 0
        // Constant 800 for the same reason as mainPanel — surface-width toggles
        // cause bigPill.x to jump mid-animation.
        implicitWidth: 800
        // Fixed 500 to match mainPanel — bigPill anchors to bigPanel.bottom,
        // so a stable surface height keeps bigPill's absolute y in lockstep
        // with toastSub's (which lives in mainPanel) during the morph.
        implicitHeight: 500
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-clock"
        exclusionMode: ExclusionMode.Ignore

        // Input mask — only bigPill and its X button capture clicks. The
        // rest of the 800-wide panel falls through to mainPanel below, so
        // the bell (and the compact toast, which shares bigPill's rest
        // geometry) stays hoverable/clickable when bigPill is invisible.
        // Gated on the same threshold as shaderEnabled: when bigPill is
        // resting at toastSub's dimensions (no shader drawn), the mask
        // collapses to zero area so toastSub receives pointer events.
        readonly property bool _maskActive: root._isBig || bigPill.height > 25
        mask: Region {
            x: bigPill.x
            y: bigPill.y
            width:  bigPanel._maskActive ? bigPill.width  : 0
            height: bigPanel._maskActive ? bigPill.height : 0
            Region {
                x: bigToastX.x
                y: bigToastX.y
                width:  bigPanel._maskActive ? bigToastX.width  : 0
                height: bigPanel._maskActive ? bigToastX.height : 0
            }
        }

        Pill {
            id: bigPill
            // Align to where the toast sub-pill sits inside mainPanel: both
            // panels share left-edge anchoring, so the same math yields the
            // same absolute x (leftEdgePad + outer pl=4 + bellSubWidth).
            x: root.leftEdgePad + 4 + pill.bellSubWidth
            anchors.bottom: parent.bottom
            // Compact-state bottom aligns with the toast sub-pill's bottom
            // (6px above the bell pill's bottom edge). Big-state bottom
            // aligns with the bell pill's bottom. Animating the margin +
            // Pill's Behavior on height together produces a continuous
            // morph from toastSub geometry to big geometry.
            anchors.bottomMargin: root._isBig
                ? root.pillBottomMargin
                : root.pillBottomMargin + 6
            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
            // Interactive so Pill's internal mouseArea drives `hovered`,
            // which in turn swaps restFill1/2 → hoverFill1/2 per Figma
            // 295:16784. clicked() signal is unwired — clicks in the body
            // are a no-op (dismiss goes through bigToastX).
            interactive: true

            // Neutral white brighter-on-hover, not the default amber.
            restFill1:  Qt.rgba(1, 1, 1, 0.048)
            restFill2:  Qt.rgba(1, 1, 1, 0.12)
            hoverFill1: Qt.rgba(1, 1, 1, 0.08)
            hoverFill2: Qt.rgba(1, 1, 1, 0.20)
            // No glow — Figma shows only a fill brighten on hover.
            glowEnabled: false

            // 300ms morph — matches the compact-pill cadence for a snappy
            // grow from the toast position.
            animationDuration: 300
            // Fill/glow snap instantly — a 5s-long glow crossfade on top of
            // the size morph would read as the pill slowly "filling in" from
            // clear, which feels wrong for an alert. Only size animates.
            animateShader: false

            // Start at the compact toast's dimensions (24 × toastSubWidth) so
            // the morph appears to grow OUT OF the compact toast, and ends at
            // the big pill's full size (54 × 276). shaderEnabled below hides
            // the pill fill/border while in compact state so it doesn't ghost
            // over toastSub underneath.
            pillHeight:     root._isBig ? root.bigPillHeight    : 24
            collapsedWidth: root._isBig ? root.bigPillFullWidth : pill.toastSubWidth
            expandedWidth:  collapsedWidth
            // Lock the corner radius to the full-pill value; without this,
            // Pill._cornerRadius = height/2 would jump as pillHeight changes.
            activeCornerRadius: root.bigPillHeight / 2
            // Fill/border visible only once the pill has grown past the
            // compact size — keeps bigPill invisible when it's resting at
            // toastSub dimensions, visible throughout the morph in both
            // directions. Symmetric: growth crosses 24 quickly, shrink
            // shows the fill all the way down to ~24.
            shaderEnabled: root._isBig || height > 25

            // Content only renders once the pill has grown enough to hold
            // it without the 24×24 icon and multi-line text being squished
            // or clipped. Threshold mirrors shaderEnabled: appears on grow,
            // disappears on shrink.
            readonly property bool _contentVisible: root._isBig || height > 40

            Image {
                id: bigImage
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                source: root._lastIcon
                visible: bigPill._contentVisible && source != ""
                sourceSize: Qt.size(48, 48)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            // Column auto-sizes to its children's actual rendered heights
            // (font ascent + descent), so the block stays tight and the
            // verticalCenter anchor lands the visual middle of the text on
            // the pill's centerline — the previous fixed-height Item left
            // extra baseline slack below the body, pushing it visibly low.
            Column {
                id: bigTextCol
                visible: bigPill._contentVisible
                anchors.left: bigImage.visible ? bigImage.right : parent.left
                anchors.leftMargin: bigImage.visible ? 8 : 12
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Item {
                    width: parent.width
                    height: bigAppName.implicitHeight

                    Text {
                        id: bigAppName
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._lastAppName
                        color: root.fgPrimary
                        font.family: "Geist"
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._lastTime
                        color: root.fgSecondary
                        font.family: "Geist"
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }
                }
                Text {
                    width: parent.width
                    // Big pill reveals the detail that the compact toast
                    // couldn't fit — prefer body, fall back to summary when
                    // the notification only sent a summary.
                    text: root._lastBody !== "" ? root._lastBody : root._lastSummary
                    color: root.fgPrimary
                    font.family: "Geist"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.letterSpacing: -0.14
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        // X button for big mode — anchored to bigPill inside this panel.
        // Uses bigPill.hovered (Pill.qml's internal MouseArea alias) so the
        // hover source is SHARED with the Pill's own fill/hover-color logic;
        // a previous dedicated MouseArea on top intercepted hover events and
        // left bigPill.hovered false (the hover fill only activated on click,
        // when the click event punched through).
        XButton {
            id: bigToastX
            visible: !root.centerOpen && root._isBig && (hovered || bigPill.hovered)
            anchors.right: bigPill.right
            anchors.rightMargin: 4
            anchors.top: bigPill.top
            anchors.topMargin: -5
            baseAlpha: 0.20
            onClicked: root.dismissToast()
        }
    }
}
