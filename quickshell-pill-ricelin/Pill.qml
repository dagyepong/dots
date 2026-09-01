pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Networking
import Quickshell.Hyprland
import "Singletons"

Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var barWindow
    property string surface: ""

    property bool hovered: false
    property bool pinned: false
    property bool forcePinned: false
    property bool hoverLatch: false
    property string linkInitialView: "main"
    property int navIndex: 0

    readonly property bool held: pinned || forcePinned
    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool expanded: surfaceOpen || held || hoverLatch

    readonly property bool mixerOpen: surface === "mixer"
    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool launcherOpen: surface === "launcher"
    readonly property bool clipboardOpen: surface === "clipboard"
    readonly property bool powerOpen: surface === "power"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool linkOpen: surface === "link"
    readonly property bool sysmonOpen: surface === "sysmon"
    readonly property bool toastActive: Notifs.popups.length > 0 && !surfaceOpen && !expanded
    readonly property var navTargets: {
        var targets = ["calendar"];
        if (pill.wifiDev !== null && pill.wifiOn)
            targets.push("wifi");
        targets.push("notifications");
        targets.push("mixer");
        targets.push("sysmon");
        if (Players.list.length > 0)
            targets.push("media");
        targets.push("power");
        return targets;
    }
    readonly property int navCursor: navTargets.length === 0
        ? -1
        : Math.max(0, Math.min(navIndex, navTargets.length - 1))
    readonly property int activeWorkspaceId: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === pill.screenName && mons[i].activeWorkspace)
                return mons[i].activeWorkspace.id;
        }
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0;
    }

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null
    readonly property real wifiLevel: (wifiActive && wifiActive.signalStrength) || 0

    signal requestSurface(string name)
    signal requestClose()
    signal requestHide()

    function surfaceItem(ld) {
        ld.active = true;
        return ld.item;
    }

    function linkBack() {
        return (pill.linkOpen && ldLink.item) ? ldLink.item.back() : false;
    }

    function linkKeyPress(key, isAutoRepeat) {
        return (pill.linkOpen && ldLink.item && ldLink.item.keyPress)
            ? ldLink.item.keyPress(key, isAutoRepeat)
            : false;
    }

    function surfaceBack() {
        if (!linkBack())
            requestClose();
    }

    function mixerStep(deltaPct) {
        return (pill.mixerOpen && ldMixer.item) ? ldMixer.item.stepFocused(deltaPct) : false;
    }

    function mixerFocusMove(dir) {
        if (pill.mixerOpen && ldMixer.item)
            ldMixer.item.moveFocus(dir);
    }

    function powerMove(dir) {
        if (pill.powerOpen && ldPower.item)
            ldPower.item.move(dir);
    }

    function powerPress() {
        return (pill.powerOpen && ldPower.item) ? ldPower.item.pressFocused() : false;
    }

    function powerRelease() {
        if (pill.powerOpen && ldPower.item)
            ldPower.item.releaseFocused();
    }

    function normalizeTopNav() {
        if (navTargets.length === 0) {
            navIndex = -1;
            return;
        }
        if (navIndex < 0)
            navIndex = 0;
        else if (navIndex >= navTargets.length)
            navIndex = navTargets.length - 1;
    }

    function navFocused(key) {
        if (!hover.live || navTargets.length === 0)
            return false;
        return navTargets[navCursor] === key;
    }

    function moveTopNav(dir) {
        if (!hover.live || navTargets.length === 0)
            return false;
        normalizeTopNav();
        navIndex = (navIndex + dir + navTargets.length) % navTargets.length;
        return true;
    }

    function activateTopNav() {
        if (!hover.live || navTargets.length === 0)
            return false;
        normalizeTopNav();

        var target = navTargets[navIndex];
        if (target === "calendar") {
            requestSurface("calendar");
        } else if (target === "wifi") {
            linkInitialView = "wifi";
            requestSurface("link");
        } else if (target === "notifications") {
            linkInitialView = "main";
            requestSurface("link");
        } else if (target === "mixer") {
            requestSurface("mixer");
        } else if (target === "sysmon") {
            requestSurface("sysmon");
        } else if (target === "media") {
            requestSurface("media");
        } else if (target === "power") {
            requestSurface("power");
        }
        return true;
    }

    function toggleKeyboardExpanded() {
        if (surfaceOpen)
            return false;
        var want = !expanded;
        pinned = want;
        hoverLatch = want;
        if (want)
            normalizeTopNav();
        else
            graceTimer.stop();
        return true;
    }

    function resetKeyboardState() {
        navIndex = 0;
        pinned = false;
        hoverLatch = false;
        graceTimer.stop();
    }

    onHoveredChanged: {
        if (hovered) {
            hoverLatch = true;
            graceTimer.stop();
        } else {
            graceTimer.restart();
        }
    }

    onSurfaceOpenChanged: if (surfaceOpen) pinned = false
    onLinkOpenChanged: if (!linkOpen) linkInitialView = "main"
    onNavTargetsChanged: normalizeTopNav()
    onExpandedChanged: if (expanded) normalizeTopNav()

    Timer {
        id: graceTimer
        interval: 260
        onTriggered: pill.hoverLatch = false
    }

    TapHandler {
        enabled: !pill.surfaceOpen
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.pinned = !pill.pinned
    }

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string hhmm: Qt.formatTime(now, "h:mm" + (Flags.clockSeconds ? ":ss" : "") + " AP")
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: Flags.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property real restW: Math.max(160 * s, restRow.implicitWidth + 36 * s)
    readonly property real restH: 38 * s
    readonly property real hoverW: hoverRow.implicitWidth + 40 * s
    readonly property real hoverH: 58 * s
    readonly property real launcherW: 360 * s
    readonly property real launcherH: 332 * s
    readonly property real clipboardW: 360 * s
    readonly property real clipboardH: 332 * s
    readonly property real mixerH: 218 * s
    readonly property real mediaW: (Players.pickable.length > 1 ? 460 : 390) * s
    readonly property real mediaH: 150 * s
    readonly property real powerW: 330 * s
    readonly property real powerH: 150 * s
    readonly property real sysmonW: Math.max(392, 260 + 132 * Math.max(1, Sysmon.gpus.length)) * s
    readonly property real toastW: 342 * s
    readonly property real openCorner: 22 * s
    readonly property real restCorner: 18 * s

    readonly property size targetSize: {
        if (launcherOpen) {
            surfaceItem(ldLauncher);
            return Qt.size(launcherW, launcherH);
        }
        if (clipboardOpen) {
            surfaceItem(ldClip);
            return Qt.size(clipboardW, clipboardH);
        }
        if (calendarOpen) {
            var cal = surfaceItem(ldCalendar);
            return Qt.size((cal && cal.implicitWidth > 0 ? cal.implicitWidth : 282 * s) + 36 * s,
                           (cal ? cal.implicitHeight : 204 * s) + 32 * s);
        }
        if (mixerOpen) {
            var mix = surfaceItem(ldMixer);
            return Qt.size(124 * Math.max(2, mix ? mix.faderCount : 2) * s, mixerH);
        }
        if (linkOpen) {
            var link = surfaceItem(ldLink);
            return Qt.size(link ? link.desiredW : 330 * s,
                           (link ? link.implicitHeight : 280 * s) + 26 * s);
        }
        if (mediaOpen) {
            surfaceItem(ldMedia);
            return Qt.size(mediaW, mediaH);
        }
        if (powerOpen) {
            surfaceItem(ldPower);
            return Qt.size(powerW, powerH);
        }
        if (sysmonOpen) {
            var sys = surfaceItem(ldSysmon);
            return Qt.size(sysmonW, (sys ? sys.implicitHeight : 220 * s) + 33 * s);
        }
        if (toastActive) {
            return Qt.size(toastW, toastLoader.item ? toastLoader.item.implicitHeight + 24 * s : 64 * s);
        }
        if (expanded)
            return Qt.size(Math.max(restW, hoverW), hoverH);
        return Qt.size(restW, restH);
    }

    readonly property real targetW: targetSize.width
    readonly property real targetH: targetSize.height

    width: targetW
    height: targetH

    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(width - targetW), Math.abs(height - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }
    readonly property real morphRadius: surfaceOpen ? openCorner : restCorner
    readonly property real materialOpacity: Math.min(Flags.pillOpacity, Theme.pillOpacity)

    Behavior on width { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: pill.morphRadius
        border.width: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, pill.materialOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, pill.materialOpacity) }
        }
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: body.radius * 0.6
            anchors.rightMargin: body.radius * 0.6
            height: 1
            color: Theme.sheen
        }
    }

    component PillIcon: Item {
        id: iconRoot
        property string glyph: ""
        property string tip: ""
        property bool active: false
        property bool focused: false
        signal clicked()

        width: 22 * pill.s
        height: 22 * pill.s

        Rectangle {
            anchors.fill: parent
            radius: 7 * pill.s
            color: iconArea.containsMouse || iconRoot.focused ? Theme.frameBg : "transparent"
            border.width: iconArea.containsMouse || iconRoot.active || iconRoot.focused ? 1 : 0
            border.color: iconRoot.focused ? Qt.alpha(Theme.vermLit, 0.85)
                : (iconRoot.active ? Qt.alpha(Theme.vermLit, 0.55) : Theme.frameBorder)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * pill.s
            height: 15 * pill.s
            name: iconRoot.glyph
            color: iconArea.containsMouse || iconRoot.active || iconRoot.focused ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            anchors.margins: -5 * pill.s
            hoverEnabled: true
            enabled: hover.live
            cursorShape: Qt.PointingHandCursor
            onClicked: iconRoot.clicked()
        }

        Tooltip {
            s: pill.s
            placement: "below"
            title: iconRoot.tip
            show: iconArea.containsMouse
        }
    }

    Item {
        id: rest
        anchors.fill: parent
        opacity: (!pill.expanded && !pill.surfaceOpen && !pill.toastActive) ? Math.pow(pill.morphCloseness, 1.4) : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        Row {
            id: restRow
            anchors.centerIn: parent
            spacing: 9 * pill.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.hhmm
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        opacity: (pill.expanded && !pill.surfaceOpen) ? Math.pow(pill.morphCloseness, 1.2) : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        readonly property bool live: pill.expanded && !pill.surfaceOpen

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 18 * pill.s

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                screenName: pill.screenName
                s: pill.s
                gap: 8 * pill.s
                enabled: hover.live
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: hoverClock.implicitWidth
                height: hoverClock.implicitHeight
                readonly property bool navFocus: pill.navFocused("calendar")

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 22 * pill.s
                    height: parent.height + 10 * pill.s
                    radius: 7 * pill.s
                    color: parent.navFocus ? Theme.frameBg : "transparent"
                    border.width: parent.navFocus ? 1 : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.85)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Column {
                    id: hoverClock
                    anchors.centerIn: parent
                    spacing: 2 * pill.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.hhmm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 18 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.date
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 8.5 * pill.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2 * pill.s
                    }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: hoverClock.implicitWidth + 22 * pill.s
                    height: hoverClock.implicitHeight + 10 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * pill.s

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.wifiDev !== null && pill.wifiOn
                    width: 22 * pill.s
                    height: 22 * pill.s
                    readonly property bool navFocus: pill.navFocused("wifi")

                    Rectangle {
                        anchors.fill: parent
                        radius: 7 * pill.s
                        color: wifiArea.containsMouse || parent.navFocus ? Theme.frameBg : "transparent"
                        border.width: wifiArea.containsMouse || parent.navFocus ? 1 : 0
                        border.color: parent.navFocus ? Qt.alpha(Theme.vermLit, 0.85) : Theme.frameBorder
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    WifiGlyph {
                        anchors.centerIn: parent
                        s: pill.s
                        level: pill.wifiLevel
                        on: pill.wifiOn
                        litColor: wifiArea.containsMouse || parent.navFocus ? Theme.cream : Theme.iconDim
                    }

                    MouseArea {
                        id: wifiArea
                        anchors.fill: parent
                        anchors.margins: -5 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pill.linkInitialView = "wifi";
                            pill.requestSurface("link");
                        }
                    }
                }

                PillIcon {
                    glyph: "inbox"
                    tip: "Notifications"
                    active: Notifs.unread > 0
                    focused: pill.navFocused("notifications")
                    onClicked: {
                        pill.linkInitialView = "main";
                        pill.requestSurface("link");
                    }
                }

                PillIcon {
                    glyph: "mixer"
                    tip: "Mixer"
                    focused: pill.navFocused("mixer")
                    onClicked: pill.requestSurface("mixer")
                }

                PillIcon {
                    glyph: "monitor"
                    tip: "System"
                    focused: pill.navFocused("sysmon")
                    onClicked: pill.requestSurface("sysmon")
                }

                PillIcon {
                    glyph: "music"
                    tip: "Media"
                    visible: Players.list.length > 0
                    focused: pill.navFocused("media")
                    onClicked: pill.requestSurface("media")
                }

                PillIcon {
                    glyph: "shutdown"
                    tip: "Power"
                    focused: pill.navFocused("power")
                    onClicked: pill.requestSurface("power")
                }
            }
        }
    }

    Loader {
        id: ldMixer
        active: false
        anchors.fill: parent
        sourceComponent: Mixer {
            s: pill.s
            open: pill.mixerOpen
            morphCloseness: pill.morphCloseness
        }
    }

    Loader {
        id: ldCalendar
        active: true
        anchors.fill: parent
        sourceComponent: Calendar {
            s: pill.s
            open: pill.calendarOpen
            morphCloseness: pill.morphCloseness
        }
    }

    Loader {
        id: ldLauncher
        active: false
        anchors.fill: parent
        sourceComponent: Launcher {
            s: pill.s
            open: pill.launcherOpen
            workspaceId: pill.activeWorkspaceId
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldClip
        active: false
        anchors.fill: parent
        sourceComponent: Clipboard {
            s: pill.s
            open: pill.clipboardOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldPower
        active: false
        anchors.fill: parent
        sourceComponent: Power {
            s: pill.s
            open: pill.powerOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldMedia
        active: false
        anchors.fill: parent
        sourceComponent: Media {
            s: pill.s
            open: pill.mediaOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldLink
        active: false
        anchors.fill: parent
        sourceComponent: Link {
            s: pill.s
            open: pill.linkOpen
            initialView: pill.linkInitialView
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldSysmon
        active: false
        anchors.fill: parent
        sourceComponent: SysmonSurface {
            s: pill.s
            open: pill.sysmonOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: toastLoader
        active: pill.toastActive
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 16 * pill.s
        anchors.rightMargin: 16 * pill.s
        anchors.bottomMargin: 12 * pill.s
        opacity: active ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        sourceComponent: Item {
            implicitHeight: toastContent.implicitHeight

            Toast {
                id: toastContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                s: pill.s
                live: toastLoader.active
                notif: Notifs.popups.length > 0 ? Notifs.popups[Notifs.popups.length - 1] : null
            }
        }
    }
}
