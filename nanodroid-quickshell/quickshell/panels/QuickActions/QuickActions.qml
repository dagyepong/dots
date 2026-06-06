import "../../core"
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Quick Actions panel — floating HUD at the bottom.
 * Uses a full-screen PanelWindow for reliable centering and slide animation.
 */
Variants {
    id: root
    model: Quickshell.screens

	    delegate: Scope {
	        id: screenScope
	        required property var modelData
	        readonly property real quickActionsFallbackWidth: Math.round(670 * Appearance.effectiveScale)

    PanelWindow {
        id: hoverTrigger
        screen: screenScope.modelData

        readonly property bool isActive: GlobalStates.activeScreen === screenScope.modelData
        visible: Config.ready && !GlobalStates.screenLocked

        anchors {
            left: true
            right: true
            bottom: true
        }

        implicitHeight: Math.max(12 * Appearance.effectiveScale, (Config.options.dock?.hoverRegionHeight ?? 5) * Appearance.effectiveScale + 8 * Appearance.effectiveScale)
        color: "transparent"
        WlrLayershell.namespace: "nandoroid:quickactions-hover"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
	        mask: Region { item: triggerArea }
	
	        MouseArea {
	            id: triggerArea
	            anchors.horizontalCenter: parent.horizontalCenter
	            anchors.top: parent.top
	            anchors.bottom: parent.bottom
	            width: panelWindow.quickActionsHoverWidth
	            hoverEnabled: true
	            acceptedButtons: Qt.NoButton
            onEntered: {
                GlobalStates.openPanelByHover("quickActions", screenScope.modelData);
            }
            onExited: {
                GlobalStates.setHoverTrigger("quickActions", false);
            }
        }
    }

    PanelWindow {
        id: panelWindow
        screen: screenScope.modelData

	        readonly property bool isActive: GlobalStates.activeScreen === screenScope.modelData
	        readonly property var monitor: Hyprland.monitorFor(screenScope.modelData)
        readonly property real quickActionsHoverWidth: Math.round(content.implicitWidth > 0
            ? content.implicitWidth
            : (content.width > 0 ? content.width : screenScope.quickActionsFallbackWidth))
	        visible: (GlobalStates.quickActionsOpen && isActive) || content.opacity > 0
        
        // Fill the screen
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        WlrLayershell.namespace: "nandoroid:quickactions"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (GlobalStates.quickActionsOpen && GlobalStates.hoverPanelName !== "quickActions") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {
            item: GlobalStates.hoverPanelName === "quickActions" ? hoverMask : fullScreenMask
        }

        function updateHoverFromCursor(globalX, globalY) {
            if (GlobalStates.hoverPanelName !== "quickActions" || !panelWindow.isActive) return;

            const monitorX = panelWindow.monitor?.x ?? 0;
            const monitorY = panelWindow.monitor?.y ?? 0;
            const localX = globalX - monitorX;
            const localY = globalY - monitorY;
            const pad = 18 * Appearance.effectiveScale;

            const insideContent = content.opacity > 0
                && localX >= content.x - pad
                && localX <= content.x + content.width + pad
                && localY >= content.y - pad
                && localY <= content.y + content.height + pad;
	            const triggerLeft = Math.round((panelWindow.width - panelWindow.quickActionsHoverWidth) / 2);
	            const insideTrigger = localX >= triggerLeft
	                && localX <= triggerLeft + panelWindow.quickActionsHoverWidth
	                && localY >= panelWindow.height - hoverTrigger.implicitHeight - pad
	                && localY <= panelWindow.height + pad;

            if (!insideContent && !insideTrigger) {
                GlobalStates.quickActionsOpen = false;
                GlobalStates.clearHoverPanelState();
                return;
            }

            GlobalStates.setHoverContent("quickActions", insideContent);
            GlobalStates.setHoverTrigger("quickActions", insideTrigger);
        }

        Process {
            id: cursorPosProc
            command: ["hyprctl", "cursorpos"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const parts = this.text.trim().split(",");
                    if (parts.length < 2) return;

                    const globalX = parseFloat(parts[0]);
                    const globalY = parseFloat(parts[1]);
                    if (Number.isFinite(globalX) && Number.isFinite(globalY)) {
                        panelWindow.updateHoverFromCursor(globalX, globalY);
                    }
                }
            }
        }

        Item {
            id: fullScreenMask
            anchors.fill: parent
        }

	        Item {
	            id: hoverMask
	            anchors.horizontalCenter: parent.horizontalCenter
	            anchors.bottom: parent.bottom
	            width: panelWindow.quickActionsHoverWidth
	            height: content.height + hoverTrigger.implicitHeight + 24 * Appearance.effectiveScale

            // Hover tracking is limited to the actual bottom hover/input region.
            // A full-screen tracker keeps containsMouse true after the cursor leaves
            // the layer-shell input mask, which prevents hover-close from firing.
            MouseArea {
                id: hoverGuardArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                function updateHoverRange(mouse) {
                    if (GlobalStates.hoverPanelName !== "quickActions" || !panelWindow.isActive) return;

                    const pad = 18 * Appearance.effectiveScale;
                    const contentPoint = mapToItem(content, mouse.x, mouse.y);
                    const insideContent = content.opacity > 0
                        && contentPoint.x >= -pad
                        && contentPoint.x <= content.width + pad
                        && contentPoint.y >= -pad
                        && contentPoint.y <= content.height + pad;
                    const insideTrigger = mouse.y >= hoverGuardArea.height - hoverTrigger.implicitHeight - pad;

                    GlobalStates.setHoverContent("quickActions", insideContent);
                    GlobalStates.setHoverTrigger("quickActions", insideTrigger);
                }
                onPositionChanged: (mouse) => updateHoverRange(mouse)
                onExited: {
                    if (GlobalStates.hoverPanelName === "quickActions") {
                        GlobalStates.setHoverContent("quickActions", false);
                        GlobalStates.setHoverTrigger("quickActions", false);
                    }
                }
            }
        }

        // Handle focus
        HyprlandFocusGrab {
            id: focusGrab
            active: GlobalStates.quickActionsOpen && panelWindow.isActive && GlobalStates.hoverPanelName !== "quickActions"
            windows: [panelWindow]
            onCleared: {
                GlobalStates.quickActionsOpen = false;
            }
        }

        // Close on click outside for keyboard/toggle-open mode.
        MouseArea {
            anchors.fill: parent
            enabled: GlobalStates.hoverPanelName !== "quickActions"
            onClicked: GlobalStates.quickActionsOpen = false
        }

        Timer {
            id: hoverValidationTimer
            interval: 120
            repeat: true
            running: GlobalStates.quickActionsOpen && GlobalStates.hoverPanelName === "quickActions" && panelWindow.isActive
            onTriggered: {
                if (!cursorPosProc.running) cursorPosProc.running = true;
            }
        }

        QuickActionsContent {
            id: content
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            
            // Initial state: pushed down by its own height
            anchors.bottomMargin: -height
            opacity: 0

            states: [
                State {
                    name: "active"
                    when: GlobalStates.quickActionsOpen && panelWindow.isActive
                    PropertyChanges {
                        target: content
                        anchors.bottomMargin: 0
                        opacity: 1
                    }
                }
            ]

            transitions: [
                Transition {
                    from: ""
                    to: "active"
                    ParallelAnimation {
                        NumberAnimation {
                            target: content
                            property: "anchors.bottomMargin"
                            duration: 220
                            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                        }
                        NumberAnimation {
                            target: content
                            property: "opacity"
                            duration: 120
                        }
                    }
                },
                Transition {
                    from: "active"
                    to: ""
                    ParallelAnimation {
                        NumberAnimation {
                            target: content
                            property: "anchors.bottomMargin"
                            to: -content.height
                            duration: 180
                            easing.bezierCurve: Appearance.animationCurves.emphasized
                        }
                        NumberAnimation {
                            target: content
                            property: "opacity"
                            to: 0
                            duration: 100
                        }
                    }
                }
            ]

            onClosed: {
                GlobalStates.quickActionsOpen = false;
            }
            
            Connections {
                target: GlobalStates
                function onQuickActionsOpenChanged() {
                    if (GlobalStates.quickActionsOpen && panelWindow.isActive) {
                        content.reset();
                        content.forceActiveFocus();
                    }
                }
            }
        }
    }
    }
}
