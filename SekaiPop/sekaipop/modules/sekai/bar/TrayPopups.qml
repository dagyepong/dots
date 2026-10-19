import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.services
import qs.modules.common.widgets

// The tray's popup layer — two PopupWindows under the bar:
//
//   - `popup`: the dropdown, a capsule with the icon of every tray app
//     that isn't pinned, centered under the tray button, when `open`
//     is true
//   - `menuPopup`: the right-click menu for one app: below the capsule
//     when the dropdown is open, or (for a right-click on a pinned icon
//     in the bar, dropdown closed) on its own, centered under that icon
//
// The menu is its own window, mapped only once the app's entries have
// arrived, so it appears at its final size and place in one go. When it
// was a part of the dropdown's window, opening it meant resizing a popup
// that was already on screen, and the compositor showed that as the
// whole popup jumping sideways for a moment. Both windows hang off the
// bar itself, so the menu is never a popup of a popup.
//
// Together with Bar.qml and TraySource.qml this is where tray clicks turn
// into real actions; TrayCollection / TrayMenu only report clicks.
//
//   left click    open the app (activate). Apps that only publish a
//                 menu (`onlyMenu`) get their menu instead.
//   middle click  the app's secondary action
//   right click   the menu
//
// `open` is owned by Bar.qml (the tray button toggles it); this asks
// for it to be closed via closeRequested() — after an action, or when
// you click anywhere outside the tray.
//
// Pin / Unpin plays out over about a quarter of a second: the icon
// shrinks away where it is (`leavingItem`), then the pin actually
// flips, and it pops in on the other side while both capsules glide to
// their new widths.
Scope {
    id: root

    // The bar's PanelWindow — popups are placed relative to it.
    property var parentWindow: null
    // This monitor's scale (scale.json), read off the bar's window. Every
    // width / height in here is in design pixels; the popup window is
    // that times this, and its contents are drawn inside a ScaleHost.
    readonly property real uiScale: root.parentWindow && root.parentWindow.uiScale ? root.parentWindow.uiScale : 1
    // TraySource: the items and the pinned set.
    property var source: null
    // The tray button, to center the dropdown under.
    property Item toggleAnchor: null

    property bool open: false

    // The bar is drawn in the Capsule style: the dropdown and the menu card wear its
    // rim / shadow / body colours (Pill.capRim). A standing bar draws Float, which
    // Bar.qml's barStyle already reports as 0.
    readonly property bool capsuleStyle: !!root.parentWindow && root.parentWindow.barStyle === 3

    // The edge the bar is on, so the popups grow out of it and shrink back into it.
    readonly property string barEdge: root.parentWindow && root.parentWindow.barPosition
        ? root.parentWindow.barPosition : "top"

    // A popup window is anchored by ONE corner and grows away from it (Bar.qml popupGravity):
    // on a top or left bar its top-left corner is at anchor.rect, but a bottom bar's window
    // grows UP from it and a right bar's grows LEFT. These give the window's real top-left
    // corner (bar-window pixels), which is what the grow / shrink origins are measured from.
    readonly property int gravity: root.parentWindow ? root.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

    function windowLeft(w) {
        return w.anchor.rect.x - ((root.gravity & Edges.Left) ? w.implicitWidth : 0)
    }

    function windowTop(w) {
        return w.anchor.rect.y - ((root.gravity & Edges.Top) ? w.implicitHeight : 0)
    }

    // The dropdown's entry and dismiss: the same as the bar's other popups
    // (SekaiPopup.qml). 0 = away, 1 = shown, overshooting a little while it pops in;
    // the window stays up until it has shrunk back into the bar.
    property real dropReveal: 0

    NumberAnimation {
        id: dropPopIn
        target: root
        property: "dropReveal"
        to: 1
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
    }

    NumberAnimation {
        id: dropSwallow
        target: root
        property: "dropReveal"
        to: 0
        duration: 170
        easing.type: Easing.InCubic
    }

    // Another popup is opening: put this one away at once if it is still on its way out.
    Connections {
        target: PopupHandoff

        function onSerialChanged() {
            if (!root.open && root.dropReveal > 0) {
                dropSwallow.stop()
                dropPopIn.stop()
                root.dropReveal = 0
            }
        }
    }

    // Click-anywhere-else-to-dismiss (Hyprland's focus grab). If clicks
    // on the dropdown ever seem to do nothing, set this to false and
    // reload: clicks work regardless, you just close it with the tray
    // button (or by picking something) instead.
    property bool useFocusGrab: true

    signal closeRequested()

    // The app whose menu is showing (null = none), and the path of
    // submenus drilled into so far (empty = the app's top-level menu).
    property var menuItem: null
    property var menuStack: []

    // Where the popup sits when it's just a menu: under the pinned icon
    // in the bar that was right-clicked (bar-window x of its middle, so
    // the menu is centered right under the icon).
    property real pinnedIconX: 0
    // Same for a standing bar (left / right): the middle of that icon,
    // top to bottom.
    property real pinnedIconY: 0

    // Air between the bar and the popups, and between the capsule and
    // the menu below it (design pixels).
    readonly property real gapTop: 6
    readonly property real gapBetween: 6

    // Transparent room around each card inside its popup window (design
    // pixels). The windows used to be exactly as big as the card, so anything
    // that moves past the card's edge was cut off at the window's edge: the
    // pop's overshoot, the capsule's own pop / bump, the hard shadow while it
    // scales. Same idea as SekaiPopup's `bleed`: every side gets room except
    // the one facing the bar (the window starts there, and the card only ever
    // grows away from it).
    readonly property real bleed: 14

    // Dropdown window: the bar side keeps `gapTop` of air instead.
    readonly property real dropPadT: barEdge === "top" ? gapTop : bleed
    readonly property real dropPadB: barEdge === "bottom" ? gapTop : bleed
    readonly property real dropPadL: barEdge === "left" ? gapTop : bleed
    readonly property real dropPadR: barEdge === "right" ? gapTop : bleed

    // Menu window: nothing on the bar side (its offset from the bar is `lead`).
    readonly property real menuPadT: barEdge === "top" ? 0 : bleed
    readonly property real menuPadB: barEdge === "bottom" ? 0 : bleed
    readonly property real menuPadL: barEdge === "left" ? 0 : bleed
    readonly property real menuPadR: barEdge === "right" ? 0 : bleed

    // The menu window is only mapped once the app's entries are in (see
    // startPop), so it never has to resize while it's on screen.
    property bool menuReady: false

    // How many entries the app's menu has published so far.
    readonly property int entryCount: opener.children ? opener.children.values.length : 0
    onEntryCountChanged: {
        if (popPending && entryCount > 0)
            popSettle.restart()
    }

    // Whether the app the menu is for is pinned, read when the menu is asked for
    // and kept while it shrinks away (the pin flips under it), so the row does
    // not change from "Unpin" to "Pin" on the way out.
    property bool menuPinned: false

    // The app that's mid-way through being pinned / unpinned; its icon
    // (in whichever capsule it's in) shrinks away before the pin flips.
    property var leavingItem: null

    // How wide the popup window is. Follows what's wanted right away
    // when that grows, but hangs on to the old width for a moment when
    // it shrinks, so the capsule can finish gliding narrower inside it —
    // resizing a popup window every frame would flicker.
    property real windowW: 0
    onWindowWChanged: console.log("[tray] popup width " + windowW)

    // True while the popup is showing just a menu under a pinned icon
    // (dropdown closed). It's remembered rather than derived from `open`
    // on purpose: `open` flips to false the moment the dropdown starts
    // closing, and positioning off that made the popup jump to the far
    // left for a frame before it disappeared.
    property bool menuOnly: false

    readonly property var menuHandle: menuStack.length > 0
        ? menuStack[menuStack.length - 1]
        : (menuItem ? menuItem.menu : null)

    // Bar-window x of the tray button's center, re-read every time the
    // dropdown opens (the clock ticking over can nudge the layout).
    readonly property real dropdownCenterX: {
        void root.open
        return toggleAnchor ? toggleAnchor.mapToItem(null, toggleAnchor.width / 2, 0).x : 0
    }

    // Same, but the button's middle top to bottom, for a standing bar.
    readonly property real dropdownCenterY: {
        void root.open
        return toggleAnchor ? toggleAnchor.mapToItem(null, 0, toggleAnchor.height / 2).y : 0
    }

    onOpenChanged: {
        if (open) {
            PopupHandoff.opening()
            dropSwallow.stop()
            dropPopIn.restart()
        } else {
            dropPopIn.stop()
            dropSwallow.restart()
        }
        // The capsule only starts animating (icons leaving, gliding
        // narrower) a moment after it is open, so it grows out of the bar as
        // one piece.
        capsuleLive = false
        if (open) {
            menuOnly = false
            shrinkHold.stop()
            windowW = wantW
            liveTimer.restart()
        } else {
            liveTimer.stop()
        }
        closeMenu()
    }

    property bool capsuleLive: false

    Timer {
        id: liveTimer
        interval: 120
        onTriggered: root.capsuleLive = true
    }

    // The menu is put away the way the other popups are: it shrinks back into
    // the bar (TrayMenu.away()), and only then is its window taken down and the
    // app forgotten (finishCloseMenu). `menuLeaving` keeps the window up and the
    // entries on the card until then.
    property bool menuLeaving: false

    function closeMenu() {
        popPending = false
        popFallback.stop()
        popSettle.stop()
        if (menuReady && menuItem !== null && menuCard.popProgress > 0.001) {
            menuLeaving = true
            menuReady = false
            menuCard.away()
            return
        }
        finishCloseMenu()
    }

    function finishCloseMenu() {
        menuLeaving = false
        menuReady = false
        menuStack = []
        menuItem = null
    }

    function closeAll() {
        closeMenu()
        if (open)
            closeRequested()
    }

    // `icon` is the clicked icon tile, `inDropdown` whether it lives in
    // the dropdown (as opposed to being a pinned icon in the bar).
    function openMenu(item, icon, inDropdown) {
        if (!item || !item.hasMenu) {
            console.log("[tray] " + (item ? item.id : "?") + " has no menu to show")
            return
        }
        // Hide the card first: from here until the app's entries have
        // landed (see startPop) it only takes up room, so the window can
        // settle at its final size before anything is seen moving.
        menuCard.hold()
        menuLeaving = false
        menuPinned = root.source ? root.source.isPinned(item) : false
        menuStack = []
        if (open) {
            menuOnly = false
        } else {
            menuOnly = true
            pinnedIconX = icon.mapToItem(null, icon.width / 2, 0).x
            pinnedIconY = icon.mapToItem(null, 0, icon.height / 2).y
        }
        menuItem = item
        startPop()
    }

    // The menu's entries arrive over D-Bus a moment after the right-click,
    // so the card is first the size of its "Pin" row alone and then grows
    // to its real size. So the menu window isn't mapped until the entries
    // are in (plus a short settle for rows that trickle in), and then it
    // appears at its final size and plays the pop-in. The fallback covers
    // a menu that publishes nothing, or entries that were already cached
    // and so never change the count. Right-clicking another icon while a
    // menu is up takes the same road: the window unmaps and maps again.
    property bool popPending: false

    function startPop() {
        menuReady = false
        popPending = true
        popFallback.restart()
        if (entryCount > 0)
            popSettle.restart()
    }

    function firePop() {
        if (!popPending)
            return
        popPending = false
        popFallback.stop()
        popSettle.stop()
        menuReady = true
        menuCard.pop()
    }

    Timer {
        id: popFallback
        interval: 160
        onTriggered: root.firePop()
    }

    Timer {
        id: popSettle
        interval: 30
        onTriggered: root.firePop()
    }

    // Pin / Unpin with a short exit for the icon before it moves.
    function pinWithAnimation(item) {
        closeMenu()
        if (!item)
            return
        leavingItem = item
        pinTimer.pendingItem = item
        pinTimer.restart()
    }

    Timer {
        id: pinTimer
        interval: 120
        property var pendingItem: null
        onTriggered: {
            if (root.source)
                root.source.togglePinned(pendingItem)
            root.leavingItem = null
            pendingItem = null
        }
    }

    // Width the dropdown window should have. It's always at least as wide
    // as a menu card, so the capsule gliding wider or narrower as icons
    // come and go never has to resize a window that's on screen (a
    // Wayland compositor can move a popup and redraw it at its new size
    // as two separate steps). The capsule stays centered in the window,
    // so it looks exactly the same.
    readonly property real wantW: open
        ? Math.max(capsule.implicitWidth, menuCard.maxWidth)
        : 0

    onWantWChanged: {
        if (!open)
            return
        if (wantW >= windowW) {
            shrinkHold.stop()
            windowW = wantW
        } else {
            shrinkHold.restart()
        }
    }


    Timer {
        id: shrinkHold
        interval: 280
        onTriggered: root.windowW = root.wantW
    }

    function handleClick(item, button, icon, inDropdown) {
        if (!item)
            return
        console.log("[tray] click " + item.id + " button=" + button
            + " onlyMenu=" + item.onlyMenu + " hasMenu=" + item.hasMenu
            + (inDropdown ? " (dropdown)" : " (pinned)"))
        if (button === Qt.RightButton) {
            openMenu(item, icon, inDropdown)
        } else if (button === Qt.MiddleButton) {
            item.secondaryActivate()
            closeAll()
        } else if (item.onlyMenu) {
            openMenu(item, icon, inDropdown)
        } else {
            item.activate()
            closeAll()
        }
    }

    // The wheel over an icon: sent to the app as a StatusNotifierItem Scroll
    // (volume apps, players and so on listen for it).
    function handleScroll(item, delta, horizontal) {
        if (item && SettingsService.flag("tray.scroll"))
            item.scroll(delta, horizontal)
    }

    // The app's own menu entries. Only reads while there's a menu open.
    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    // Click anywhere else (another window, the desktop) to dismiss.
    // The bar is on the list too, so clicking the tray button or a
    // pinned icon isn't treated as clicking away.
    //
    // Switched on a beat after the popup appears, so its surface exists
    // and is on the whitelist before the grab starts (a grab that
    // doesn't know about the popup treats clicks *on* it as clicking
    // away, and closes it before the click lands).
    readonly property bool grabWanted: useFocusGrab && (popup.visible || menuPopup.visible)

    onGrabWantedChanged: {
        if (grabWanted) {
            grabDelay.restart()
        } else {
            grabDelay.stop()
            grab.active = false
        }
    }

    Timer {
        id: grabDelay
        interval: 80
        onTriggered: grab.active = root.grabWanted
    }

    HyprlandFocusGrab {
        id: grab
        windows: [popup, menuPopup, root.parentWindow]
        onCleared: {
            console.log("[tray] focus grab cleared (click outside the tray)")
            root.closeAll()
        }
    }

    // The dropdown: just the capsule.
    PopupWindow {
        id: popup

        visible: (root.open || root.dropReveal > 0.001) && root.parentWindow !== null

        // On a flat bar the popup's top-left corner goes at (x, bottom of
        // the bar), straight below it (or above it, on a bottom bar), and
        // x is clamped so the popup can't run off either side. On a
        // standing bar it goes beside the bar instead, with its top
        // level with the button. The bar decides which (Bar.qml popupX /
        // popupY).
        anchor.window: root.parentWindow
        anchor.rect.x: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            if (pw.vertical)
                return pw.popupX(0, 0, popup.implicitWidth, popup.implicitHeight)
            const wanted = root.dropdownCenterX - popup.implicitWidth / 2
            const maxX = pw.width - popup.implicitWidth - 8
            return Math.max(8, Math.min(wanted, maxX))
        }
        anchor.rect.y: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            if (!pw.vertical)
                return pw.popupY(0, 0, popup.implicitWidth, popup.implicitHeight)
            return Math.max(8, Math.min(root.dropdownCenterY - (20 + root.dropPadT - root.gapTop) * root.uiScale,
                                        pw.height - popup.implicitHeight - 8))
        }
        anchor.gravity: root.parentWindow ? root.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

        onVisibleChanged: console.log("[tray] popup " + (visible ? "shown" : "hidden"))

        implicitWidth: Math.max(1, Math.ceil((root.windowW + root.dropPadL + root.dropPadR) * root.uiScale))
        implicitHeight: Math.max(1, Math.ceil(content.implicitHeight * root.uiScale))
        color: "transparent"

        ScaleHost {
            anchors.fill: parent
            factor: root.uiScale
            // Nothing is clickable while it is being swallowed.
            enabled: root.open

            Item {
                id: content

                // Grows out of the bar's edge from nothing and shrinks all the way
                // back into it (no fade to hide the end), like the other popups.
                // The point it grows out of and shrinks into is the middle of the tray
                // button, outside the window: the whole capsule goes into the pill
                // (and so no piece is left to fade). It fades in a touch, never out.
                opacity: root.open ? Math.min(1, root.dropReveal * 8) : 1
                transform: Scale {
                    origin.x: (root.dropdownCenterX - root.windowLeft(popup)) / root.uiScale
                    origin.y: (root.dropdownCenterY - root.windowTop(popup)) / root.uiScale
                    xScale: Math.max(0, root.dropReveal)
                    yScale: Math.max(0, root.dropReveal)
                }

                // Sized by the window's width (which is held while shrinking);
                // its height is the capsule plus the transparent room around it.
                implicitHeight: root.dropPadT + capsule.height + root.dropPadB

                // Explicit, so the items inside are always within their
                // parent's bounds (and so always hit-testable).
                width: root.windowW + root.dropPadL + root.dropPadR
                height: implicitHeight

                // The window is centered under the tray button, and the
                // capsule is centered in the window, so the capsule grows
                // and shrinks evenly around the button.
                TrayCollection {
                    id: capsule
                    capRim: root.capsuleStyle
                    visible: root.open || root.dropReveal > 0.001
                    animated: root.capsuleLive
                    // Centred under the button on a flat bar; against the bar on a standing one
                    // (the window is as wide as a menu card, and a capsule left floating in the
                    // middle of it would hang far from the bar).
                    x: root.dropPadL + (root.parentWindow && root.parentWindow.vertical
                        ? (root.barEdge === "right" ? root.windowW - width : 0)
                        : (root.windowW - width) / 2)
                    y: root.dropPadT
                    width: shownWidth
                    model: root.source ? root.source.unpinnedItems : []
                    activeItem: root.menuItem
                    leavingItem: root.leavingItem
                    onItemClicked: (item, button, icon) => root.handleClick(item, button, icon, true)
                    onItemScrolled: (item, delta, horizontal) => root.handleScroll(item, delta, horizontal)
                    scrollEnabled: SettingsService.flag("tray.scroll")
                }
            }
        }
    }

    // The right-click menu. Its own window, mapped once the entries are
    // in (menuReady), centered under the tray button / pinned icon it
    // belongs to. Same width whatever the menu holds, so the card sits in
    // the middle of it and the window never has to widen.
    PopupWindow {
        id: menuPopup

        visible: (root.menuReady || root.menuLeaving) && root.menuItem !== null && root.parentWindow !== null

        // Design pixels from the bar's edge to the near edge of the card:
        // just the gap for a pinned icon's menu, or past the capsule too
        // when the dropdown is open.
        readonly property real lead: root.menuOnly
            ? root.gapTop
            : root.gapTop + capsule.height + root.gapBetween

        anchor.window: root.parentWindow
        anchor.rect.x: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            if (pw.vertical)
                return pw.popupX(0, 0, menuPopup.implicitWidth, menuPopup.implicitHeight)
            const cx = root.menuOnly ? root.pinnedIconX : root.dropdownCenterX
            const maxX = pw.width - menuPopup.implicitWidth - 8
            return Math.max(8, Math.min(cx - menuPopup.implicitWidth / 2, maxX))
        }
        anchor.rect.y: {
            const pw = root.parentWindow
            if (!pw)
                return 0
            const lead = menuPopup.lead * root.uiScale
            if (!pw.vertical) {
                const base = pw.popupY(0, 0, menuPopup.implicitWidth, menuPopup.implicitHeight)
                // The bar's far side is where a popup grows from, so on a
                // bottom bar the menu goes up from the bar instead.
                return pw.barPosition === "bottom" ? base - lead : base + lead
            }
            const cy = root.menuOnly ? root.pinnedIconY : root.dropdownCenterY
            return Math.max(8, Math.min(cy - (20 + root.menuPadT) * root.uiScale + lead,
                                        pw.height - menuPopup.implicitHeight - 8))
        }
        anchor.gravity: root.parentWindow ? root.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

        onVisibleChanged: console.log("[tray] menu popup " + (visible ? "shown" : "hidden")
            + (visible ? " " + implicitWidth + "x" + implicitHeight : ""))

        implicitWidth: Math.max(1, Math.ceil((menuCard.maxWidth + root.menuPadL + root.menuPadR) * root.uiScale))
        implicitHeight: Math.max(1, Math.ceil((menuCard.height + root.menuPadT + root.menuPadB) * root.uiScale))
        color: "transparent"

        ScaleHost {
            anchors.fill: parent
            factor: root.uiScale

            TrayMenu {
                id: menuCard

                capRim: root.capsuleStyle
                // Centred under the icon on a flat bar. The window is always as wide as the
                // widest menu there could be, so beside a standing bar the card goes against
                // the bar's side of it: centred, it hung about 70 px away from the bar.
                x: root.menuPadL + (root.parentWindow && root.parentWindow.vertical
                    ? (root.barEdge === "right" ? maxWidth - width : 0)
                    : (maxWidth - width) / 2)
                y: root.menuPadT

                // Grows from its own middle (the card sits right under
                // the icon / button). Beside a standing bar it grows
                // from the edge nearest the bar instead.
                // Into the pill it belongs to: the pinned icon in the bar, or the tray
                // button when the dropdown is open. (Outside the card, so all of it goes.)
                originX: ((root.menuOnly ? root.pinnedIconX : root.dropdownCenterX)
                    - root.windowLeft(menuPopup)) / root.uiScale - x
                originY: ((root.menuOnly ? root.pinnedIconY : root.dropdownCenterY)
                    - root.windowTop(menuPopup)) / root.uiScale - y

                onAwayDone: {
                    if (root.menuLeaving)
                        root.finishCloseMenu()
                }

                entries: opener.children
                texel: root.uiScale * Screen.devicePixelRatio
                pinned: root.menuPinned
                showPin: root.menuStack.length === 0
                showBack: root.menuStack.length > 0

                onPinRequested: root.pinWithAnimation(root.menuItem)
                onBackRequested: root.menuStack = root.menuStack.slice(0, -1)
                onSubmenuRequested: entry => root.menuStack = root.menuStack.concat([entry])
                onEntryTriggered: entry => {
                    entry.triggered()
                    root.closeAll()
                }
            }
        }
    }
}
