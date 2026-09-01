//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

ShellRoot {
    id: root

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""
    property string edgeHoverMon: ""

    function refresh() {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        refresh();
        Weather.refresh();
        startupRefresh.restart();
    }

    Timer {
        id: startupRefresh
        interval: 150
        repeat: false
        onTriggered: root.refresh()
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "pill-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    Process {
        running: Flags.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Quickshell pill",
                  "--why=keep awake", "--mode=block", "sleep", "infinity"]
    }

    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.refreshEvents[event.name])
                root.refresh();
        }
    }

    function monitorName(mon) {
        if (!mon || mon.length === 0)
            mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        return mon;
    }

    function monitorFullscreen(mon) {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === mon) {
                var ws = mons[i].activeWorkspace;
                var o = ws ? ws.lastIpcObject : null;
                return o ? !!o.hasfullscreen : false;
            }
        }
        return false;
    }

    function toggleSurface(mon, surface) {
        mon = root.monitorName(mon);
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
    }

    function hideAll() {
        root.close();
        root.peekMon = "";
        root.edgeHoverMon = "";
    }

    function peek(mon) {
        mon = root.monitorName(mon);
        if ((root.openMon === mon && root.openSurface.length > 0) || root.peekMon === mon) {
            root.hideAll();
            return;
        }
        root.close();
        root.peekMon = mon;
    }

    IpcHandler {
        target: "pill"
        function mixer(mon: string): void { root.toggleSurface(mon, "mixer"); }
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function power(mon: string): void { root.toggleSurface(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function media(mon: string): void {
            if (Players.list.length > 0)
                root.toggleSurface(mon, "media");
        }
        function sysmon(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function system(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { root.hideAll(); }
        function page(mon: string, name: string): void {
            var allowed = {
                mixer: true, calendar: true, launcher: true, power: true,
                clipboard: true, link: true, media: true, sysmon: true,
                system: true
            };
            if (allowed[name])
                root.toggleSurface(mon, name === "system" ? "sysmon" : name);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserve
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property real restHeight: 38 * s
            readonly property real reservedH: 0

            screen: modelData
            visible: false
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            aboveWindows: false

            anchors { top: true; left: true; right: true }
            implicitHeight: 1

            mask: emptyReserve
            Region { id: emptyReserve }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: edgeTrigger
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property bool monFullscreen: root.monitorFullscreen(modelData.name)

            screen: modelData
            visible: !monFullscreen && root.openSurface.length === 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pill-edge-trigger"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; left: true; right: true }
            implicitHeight: Math.max(4, 4 * s)

            mask: edgeRegion
            Region {
                id: edgeRegion
                readonly property real triggerW: Math.min(edgeTrigger.width, Math.max(240 * edgeTrigger.s, 320 * edgeTrigger.s))
                x: (edgeTrigger.width - triggerW) / 2
                y: 0
                width: triggerW
                height: edgeTrigger.height
            }

            onMonFullscreenChanged: if (monFullscreen && root.edgeHoverMon === modelData.name)
                root.edgeHoverMon = "";

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    clearEdgeHover.stop();
                    root.edgeHoverMon = edgeTrigger.modelData.name;
                }
                onExited: clearEdgeHover.restart()
            }

            Timer {
                id: clearEdgeHover
                interval: 260
                onTriggered: if (root.edgeHoverMon === edgeTrigger.modelData.name)
                    root.edgeHoverMon = "";
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool toggledOpen: root.peekMon === modelData.name
            readonly property bool edgeHovered: root.edgeHoverMon === modelData.name
            readonly property bool userVisible: surfaceOpen || toggledOpen || edgeHovered || pill.hoverLatch
            readonly property bool shellShown: surfaceOpen || toggledOpen || edgeHovered || pill.hoverLatch || pill.toastActive
            readonly property bool modal: surfaceOpen || toggledOpen

            readonly property bool monFullscreen: root.monitorFullscreen(modelData.name)
            readonly property bool edgeHoverable: !monFullscreen && !modal && root.openSurface.length === 0

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
                if (root.edgeHoverMon === modelData.name) root.edgeHoverMon = "";
                pill.pinned = false;
            }

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: userVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: "pill"

            anchors { top: true; left: true; right: true; bottom: true }

            mask: monFullscreen ? hiddenRegion : (modal ? fullRegion : (shellShown ? overlayRevealRegion : overlayEdgeRegion))
            Region { id: hiddenRegion }
            Region {
                id: overlayEdgeRegion
                readonly property real triggerW: Math.min(overlay.width, Math.max(320 * overlay.s, pill.targetW))
                x: (overlay.width - triggerW) / 2
                y: 0
                width: triggerW
                height: Math.max(8, 8 * overlay.s)
            }
            Region {
                id: overlayRevealRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                readonly property real triggerW: Math.min(overlay.width, Math.max(baseW, 320 * overlay.s))
                x: (overlay.width - triggerW) / 2
                y: 0
                width: triggerW
                height: Math.max(pill.y + Math.max(pill.height, pill.targetH), overlayEdgeRegion.height)
            }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                x: pill.x + (pill.width - baseW) / 2
                y: pill.y
                width: baseW
                height: Math.max(pill.height, pill.targetH)
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }

            MouseArea {
                id: edgeHoverArea
                x: overlayRevealRegion.x
                y: overlayRevealRegion.y
                width: overlayRevealRegion.width
                height: overlayRevealRegion.height
                enabled: overlay.edgeHoverable
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    clearOverlayEdgeHover.stop();
                    root.edgeHoverMon = overlay.modelData.name;
                }
                onExited: clearOverlayEdgeHover.restart()
            }

            Timer {
                id: clearOverlayEdgeHover
                interval: 260
                onTriggered: if (root.edgeHoverMon === overlay.modelData.name)
                    root.edgeHoverMon = "";
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    if (overlay.surfaceOpen) {
                        var inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                            && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                        if (!inside)
                            root.close();
                        else if (mouse.y <= pillRegion.y + 40 * pill.s)
                            pill.surfaceBack();
                    } else {
                        pill.pinned = false;
                        root.peekMon = "";
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.userVisible

                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Escape || e.key === Qt.Key_Backspace) {
                        if (pill.surfaceOpen) {
                            if (!pill.linkBack())
                                root.close();
                        } else {
                            root.hideAll();
                            pill.resetKeyboardState();
                        }
                        e.accepted = true;
                        return;
                    }

                    if (!pill.surfaceOpen) {
                        if (e.key === Qt.Key_Space) {
                            pill.toggleKeyboardExpanded();
                            e.accepted = true;
                        } else if (pill.expanded
                            && (e.key === Qt.Key_H || e.key === Qt.Key_K
                                || e.key === Qt.Key_Left || e.key === Qt.Key_Up)) {
                            e.accepted = pill.moveTopNav(-1);
                        } else if (pill.expanded
                            && (e.key === Qt.Key_L || e.key === Qt.Key_J
                                || e.key === Qt.Key_Right || e.key === Qt.Key_Down)) {
                            e.accepted = pill.moveTopNav(1);
                        } else if (pill.expanded
                            && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) {
                            e.accepted = pill.activateTopNav();
                        }
                        return;
                    }

                    if (pill.linkOpen) {
                        e.accepted = pill.linkKeyPress(e.key, e.isAutoRepeat);
                        return;
                    }

                    if (pill.mixerOpen) {
                        if (e.key === Qt.Key_H || e.key === Qt.Key_Left) {
                            pill.mixerFocusMove(-1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_L || e.key === Qt.Key_Right) {
                            pill.mixerFocusMove(1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_K || e.key === Qt.Key_Up) {
                            e.accepted = pill.mixerStep(1);
                        } else if (e.key === Qt.Key_J || e.key === Qt.Key_Down) {
                            e.accepted = pill.mixerStep(-1);
                        }
                        return;
                    }

                    if (pill.powerOpen) {
                        if (e.key === Qt.Key_H || e.key === Qt.Key_K
                            || e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
                            pill.powerMove(-1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_L || e.key === Qt.Key_J
                            || e.key === Qt.Key_Right || e.key === Qt.Key_Down) {
                            pill.powerMove(1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                            if (!e.isAutoRepeat) pill.powerPress();
                            e.accepted = true;
                        }
                        return;
                    }
                }
                Keys.onReleased: (e) => {
                    if (e.isAutoRepeat)
                        return;
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                        && pill.powerOpen) {
                        pill.powerRelease();
                        e.accepted = true;
                    }
                }

                Pill {
                    id: pill
                    anchors.top: parent.top
                    anchors.topMargin: overlay.topGap
                    anchors.horizontalCenter: parent.horizontalCenter
                    s: overlay.s
                    screenName: overlay.modelData.name
                    barWindow: overlay
                    surface: overlay.surface
                    forcePinned: false

                    HoverHandler {
                        enabled: overlay.shellShown
                        onHoveredChanged: pill.hovered = hovered
                    }

                    opacity: (overlay.monFullscreen || !overlay.shellShown) ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
                    transform: Translate {
                        y: (overlay.monFullscreen || !overlay.shellShown) ? -(pill.height + overlay.topGap) : 0
                        Behavior on y { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
                    }

                    onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                    onRequestClose: root.close()
                    onRequestHide: root.hideAll()
                }
            }

            onSurfaceOpenChanged: if (surfaceOpen) focusScope.forceActiveFocus()
            onUserVisibleChanged: if (userVisible) focusScope.forceActiveFocus()
        }
    }
}
