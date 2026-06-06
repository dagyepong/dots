import "../../core"
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Notification Center panel — aligned to the visible left edge of the status bar.
 * Uses a full-width overlay like Dashboard so the joined edge is deterministic.
 */
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: panelWindow
        required property var modelData
        screen: modelData

        readonly property bool isActive: GlobalStates.activeScreen === modelData
        visible: (GlobalStates.notificationCenterOpen && isActive) || panelGroup.opacity > 0

        exclusiveZone: 0
        WlrLayershell.namespace: "nandoroid:notificationCenter"
        WlrLayershell.layer: ((GlobalStates.notificationCenterOpen || panelGroup.opacity > 0) && isActive) ? WlrLayer.Overlay : WlrLayer.Background
        WlrLayershell.keyboardFocus: (GlobalStates.notificationCenterOpen && isActive && GlobalStates.hoverPanelName !== "notifications") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        readonly property bool isCentered: (Config.ready && Config.options.statusBar) ? Config.options.statusBar.layoutStyle === "centered" : false
        readonly property real centeredWidth: Math.round((Config.ready && Config.options.statusBar ? Config.options.statusBar.centeredWidth : 1200) * Appearance.effectiveScale)
        readonly property real barWidth: isCentered ? Math.min(centeredWidth, modelData.width - 40 * Appearance.effectiveScale) : modelData.width
        readonly property real barLeft: isCentered ? Math.round((modelData.width - barWidth) / 2) : 0
        readonly property real sideInset: Math.max(12 * Appearance.effectiveScale, panelWindow.shoulderRadius)
        readonly property bool hoverJoined: GlobalStates.notificationCenterOpen && isActive
        readonly property int shoulderRadius: Math.round((Config.ready && Config.options.statusBar
            ? (Config.options.statusBar.backgroundCornerRadius ?? 20) : 20) * Appearance.effectiveScale)
        readonly property real joinOverlap: Math.max(1, Math.round(2 * Appearance.effectiveScale))
        readonly property real contentWidth: contentLoader.item ? contentLoader.item.implicitWidth : Appearance.sizes.notificationCenterWidth
        readonly property real contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: GlobalStates.hoverPanelName === "notifications" ? hoverMask : fullScreenMask
        }

        Item {
            id: fullScreenMask
            anchors.fill: parent
        }

        Item {
            id: hoverMask
            x: panelWindow.barLeft + panelWindow.sideInset
            y: -panelWindow.joinOverlap
            width: panelWindow.contentWidth + (panelWindow.shoulderRadius * 2)
            height: panelWindow.contentHeight + panelWindow.shoulderRadius + panelWindow.joinOverlap
        }

        MouseArea {
            anchors.fill: parent
            enabled: GlobalStates.hoverPanelName !== "notifications"
            onClicked: {
                if (contentLoader.item) contentLoader.item.close();
                else GlobalStates.notificationCenterOpen = false;
            }
        }

        HyprlandFocusGrab {
            id: focusGrab
            active: GlobalStates.notificationCenterOpen && isActive && GlobalStates.hoverPanelName !== "notifications"
            windows: [panelWindow]
            onCleared: {
                if (contentLoader.item) contentLoader.item.close();
                else GlobalStates.notificationCenterOpen = false;
            }
        }

        Connections {
            target: GlobalStates
            function onNotificationCenterOpenChanged() {
                if (!GlobalStates.notificationCenterOpen && contentLoader.item) contentLoader.item.close();
            }
        }

        Item {
            id: panelGroup
            x: panelWindow.barLeft + panelWindow.sideInset
            y: -panelWindow.joinOverlap
            width: panelWindow.contentWidth + (panelWindow.shoulderRadius * 2)
            height: panelWindow.contentHeight + panelWindow.joinOverlap
            visible: opacity > 0 && panelWindow.isActive
            enabled: GlobalStates.notificationCenterOpen && panelWindow.isActive
            clip: true

            HoverHandler {
                enabled: panelWindow.isActive && (GlobalStates.notificationCenterOpen || panelGroup.opacity > 0)
                onHoveredChanged: GlobalStates.setHoverContent("notifications", hovered)
            }

            states: [
                State {
                    name: "open"
                    when: GlobalStates.notificationCenterOpen && panelWindow.isActive
                    PropertyChanges { target: panelGroup; opacity: 1 }
                    PropertyChanges { target: visualGroup; y: 0 }
                },
                State {
                    name: "closed"
                    when: (!GlobalStates.notificationCenterOpen || !panelWindow.isActive)
                    PropertyChanges { target: panelGroup; opacity: 0 }
                    PropertyChanges { target: visualGroup; y: -visualGroup.height }
                }
            ]

            transitions: [
                Transition {
                    from: "closed"; to: "open"
                    ParallelAnimation {
                        NumberAnimation {
                            target: visualGroup
                            property: "y"
                            duration: Appearance.animation.elementMove.duration
                            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                        }
                        NumberAnimation {
                            target: panelGroup
                            property: "opacity"
                            duration: Appearance.animation.elementMove.duration
                            easing.bezierCurve: Appearance.animationCurves.standard
                        }
                    }
                },
                Transition {
                    from: "open"; to: "closed"
                    ParallelAnimation {
                        NumberAnimation {
                            target: visualGroup
                            property: "y"
                            duration: Appearance.animation.elementMove.duration
                            easing.bezierCurve: Appearance.animationCurves.emphasized
                        }
                        NumberAnimation {
                            target: panelGroup
                            property: "opacity"
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.bezierCurve: Appearance.animationCurves.emphasized
                        }
                    }
                }
            ]

            Item {
                id: visualGroup
                x: 0
                y: -height
                width: parent.width
                height: panelWindow.contentHeight

                Loader {
                    id: contentLoader
                    x: panelWindow.shoulderRadius
                    y: 0
                    width: item ? item.implicitWidth : 0
                    height: item ? item.implicitHeight : 0
                    active: true

                    sourceComponent: NotificationCenterContent {
                        joinedToBar: panelWindow.hoverJoined
                        onClosed: {
                            GlobalStates.notificationCenterOpen = false;
                        }
                    }
                }

                RoundCorner {
                    anchors.right: contentLoader.left
                    y: contentLoader.y
                    implicitSize: panelWindow.shoulderRadius
                    corner: RoundCorner.CornerEnum.TopRight
                    color: Appearance.colors.colStatusBarSolid
                    opacity: panelWindow.hoverJoined ? 1 : 0
                    visible: opacity > 0
                }

                RoundCorner {
                    anchors.left: contentLoader.right
                    y: contentLoader.y
                    implicitSize: panelWindow.shoulderRadius
                    corner: RoundCorner.CornerEnum.TopLeft
                    color: Appearance.colors.colStatusBarSolid
                    opacity: panelWindow.hoverJoined ? 1 : 0
                    visible: opacity > 0
                }
            }
        }
    }
}
