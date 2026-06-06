import "../../core"
import "../../core/functions" as Functions
import "../../services"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool pinned: Config.ready ? (Config.options.dock.pinnedOnStartup !== undefined ? Config.options.dock.pinnedOnStartup : false) : false

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: screenScope
            required property var modelData
            readonly property int monitorIndex: modelData.index !== undefined ? modelData.index : 0

            PanelWindow {
                id: dockWindow
                screen: modelData

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "nandoroid:dock"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0

                anchors { left: true; top: true; bottom: true }
                color: "transparent"
                implicitWidth: 76 * Appearance.effectiveScale
                implicitHeight: modelData.height

                mask: Region { item: dockMouseArea }

                visible: {
                    if (!Config.ready || GlobalStates.screenLocked || !Config.options.dock.enable) return false;
                    return true;
                }

                readonly property real dockScale: (Config.ready && Config.options.dock ? Config.options.dock.scale : 1.0) * Appearance.effectiveScale
                readonly property real visualScale: dockScale / Appearance.effectiveScale
                readonly property real screenX: 0
                property bool hoverActive: false
                property bool hoverGrace: false

                readonly property bool hasActiveWindows: {
                    if (!Config.ready || !HyprlandData.activeWorkspace) return false;

                    const monitor = Hyprland.monitorFor(modelData);
                    const wsId = (monitor && monitor.activeWorkspace && monitor.activeWorkspace.id !== undefined)
                        ? monitor.activeWorkspace.id
                        : HyprlandData.activeWorkspace.id;
                    const windows = HyprlandData.hyprlandClientsForWorkspace(wsId);
                    const ignoredRegexes = Config.options.dock.ignoredAppRegexes !== undefined ? Config.options.dock.ignoredAppRegexes : [];

                    for (let i = 0; i < windows.length; i++) {
                        const w = windows[i];
                        const appClass = w.class || w.initialClass || w.appId || "";
                        let ignored = false;
                        for (let j = 0; j < ignoredRegexes.length; j++) {
                            if (new RegExp(ignoredRegexes[j], "i").test(appClass)) {
                                ignored = true;
                                break;
                            }
                        }
                        if (ignored) continue;
                        if (w.monitor === screenScope.monitorIndex && w.mapped && !w.hidden) return true;
                    }
                    return false;
                }

                property bool reveal: {
                    if (!Config.ready) return true;
                    if (root.pinned) return true;
                    if (!Config.options.dock.autoHide) return true;
                    
                    if (hoverActive || hoverGrace || dockApps.buttonHovered) return true;
                    if (dockContextMenu && dockContextMenu.visible) return true;
                    
                    // Smart auto-hide (autoHideMode === 0): hide when windows overlap/active
                    if (Config.options.dock.autoHideMode === 0) {
                        return !hasActiveWindows;
                    }
                    
                    // Always auto-hide (autoHideMode === 1)
                    return false;
                }

                onRevealChanged: {
                    if (!reveal) dockPreview.close();
                }

                Timer {
                    id: dockHideGraceTimer
                    interval: 220
                    repeat: false
                    onTriggered: dockWindow.hoverGrace = false
                }

                function keepOpenFromHover() {
                    hoverActive = true;
                    hoverGrace = true;
                    dockHideGraceTimer.stop();
                }

                function releaseHover() {
                    hoverActive = false;
                    if (dockApps.buttonHovered || (dockContextMenu && dockContextMenu.visible)) return;
                    dockHideGraceTimer.restart();
                }

                MouseArea {
                    id: dockMouseArea
                    anchors.left: parent.left
                    anchors.leftMargin: dockWindow.reveal ? visualContainer.anchors.leftMargin : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: dockWindow.reveal
                        ? visualContainer.width * dockWindow.visualScale + 2 * Appearance.effectiveScale
                        : 10 * Appearance.effectiveScale
                    height: dockWindow.reveal
                        ? Math.max(80 * Appearance.effectiveScale, visualContainer.height * dockWindow.visualScale - 24 * Appearance.effectiveScale)
                        : Math.max(110 * Appearance.effectiveScale, visualContainer.height * dockWindow.visualScale - 34 * Appearance.effectiveScale)
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: dockWindow.keepOpenFromHover()
                    onExited: dockWindow.releaseHover()
                }

                Item {
                    id: visualContainer
                    width: dockApps.implicitWidth
                    height: dockApps.implicitHeight
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: dockWindow.reveal ? 8 * Appearance.effectiveScale : -width - 10 * Appearance.effectiveScale
                    opacity: dockWindow.reveal ? 1 : 0
                    scale: dockWindow.visualScale
                    transformOrigin: Item.Left

                    Behavior on anchors.leftMargin {
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type }
                    }
                    Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                    DockApps {
                        id: dockApps
                        anchors.centerIn: parent
                        buttonPadding: 5 * Appearance.effectiveScale
                        spacing: 7 * Appearance.effectiveScale
                        backgroundStyle: Config.ready && Config.options.dock ? Config.options.dock.backgroundStyle : 1
                        availableHeight: modelData.height - 44 * Appearance.effectiveScale

                        onRequestContextMenu: (appData, x, y) => {
                            dockContextMenu.openAt(x, y, appData);
                        }

                        onButtonHoverChanged: (button, appData, hovered) => {
                            if (hovered) {
                                dockApps.lastHoveredAppData = appData;
                            }
                            dockPreview.close();
                        }
                    }
                }

                DockContextMenu { id: dockContextMenu; screen: modelData }
                DockPreview { id: dockPreview; parentWindow: dockWindow }
            }
        }
    }
}
