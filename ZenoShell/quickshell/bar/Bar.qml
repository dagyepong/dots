import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

Scope {
    // Start the lid watcher (Lid service)
    property bool lidActive: Lid.enabled

    // Vertical style: reserve the work area (bar on the left, thin frame on the other sides)
    Variants {
        model: Style.current === "side" ? Quickshell.screens : []

        Scope {
            id: reserve

            required property var modelData

            EdgeReserve { screen: reserve.modelData; edge: "left"; size: 46 }
            EdgeReserve { screen: reserve.modelData; edge: "top"; size: 8 }
            EdgeReserve { screen: reserve.modelData; edge: "right"; size: 8 }
            EdgeReserve { screen: reserve.modelData; edge: "bottom"; size: 8 }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            // Vertical style: the window covers the whole screen (frame + bar + panels); the work area is
            // reserved by the thin windows of EdgeReserve
            readonly property bool sideStyle: Style.current === "side"

            anchors {
                top: true
                left: true
                right: true
                bottom: win.sideStyle
            }
            margins {
                top: (win.sideStyle || win.attachedDash) ? 0 : Theme.topMargin
            }

            // Style chosen from the picker (qs ipc call style toggle)
            readonly property bool classic: Style.current === "classic"
            readonly property bool dashStyle: Style.current === "dash"
            // Dashboard "Attached" version: the bar is fused with the top edge of the screen
            readonly property bool attachedDash: dashStyle && Style.dashAttached
            // The island that drives keyboard shortcuts (Alt+1/2/3, Esc)
            readonly property var ctl: win.sideStyle ? popouts : (win.dashStyle ? dash : control)
            // Islands of the Island / Classic styles
            readonly property bool islands: !win.dashStyle && !win.sideStyle

            // Fixed transparent window: the islands are what grows
            implicitWidth: 600
            implicitHeight: 620
            color: "transparent"

            exclusionMode: ExclusionMode.Normal
            // -1: in the Vertical style the window covers the whole screen, ignoring the zones reserved by EdgeReserve
            exclusiveZone: win.sideStyle ? -1 : Theme.islandHeight

            // Launcher, power, authentication: exclusive keyboard (you can type right away).
            // Wi-Fi password: only on request.
            WlrLayershell.keyboardFocus: (clock.wantsKeyboard || win.typeToLaunch || (win.sideStyle ? popouts.wantsKeyboard : win.ctl.expanded)) ? WlrKeyboardFocus.Exclusive
                                         : (win.ctl.needsKeyboard ? WlrKeyboardFocus.OnDemand
                                                                  : WlrKeyboardFocus.None)

            // Empty desktop (no window on this monitor's active workspace)
            readonly property bool typeToLaunch: Compositor.emptyDesktop(win.modelData.name)

            onTypeToLaunchChanged: if (typeToLaunch) typer.forceActiveFocus()

            // Typing on the empty desktop opens the launcher with what you typed
            Item {
                id: typer
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    // Control island open: Alt+1/2/3 switches page, Esc closes it
                    if (win.ctl.expanded) {
                        if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                            win.ctl.gotoPage(event.key - Qt.Key_1)
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Escape) {
                            win.ctl.close()
                            event.accepted = true
                            return
                        }
                    }
                    const t = event.text
                    const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
                    if (!win.typeToLaunch || mods !== 0) return
                    if (t.length !== 1 || t < " " || t === " " || t === "\u007f") return

                    UiState.launcherInitial = t
                    UiState.launcherScreen = win.modelData.name
                    UiState.powerOpen = false
                    UiState.launcherOpen = true
                    event.accepted = true
                }
            }

            // With the control island open the bar listens for keys (Alt+1/2/3)
            Connections {
                target: win.ctl
                function onExpandedChanged() {
                    if (win.ctl.expanded && !win.sideStyle) typer.forceActiveFocus()
                }
            }

            // Same for the launcher / power panel of the Vertical style
            Connections {
                target: popouts
                function onExpandedChanged() {
                    if (!popouts.expanded && win.typeToLaunch) typer.forceActiveFocus()
                }
            }

            // Once the launcher is closed on an empty desktop, the bar listens again
            Connections {
                target: clock
                function onWantsKeyboardChanged() {
                    if (!clock.wantsKeyboard && win.typeToLaunch) typer.forceActiveFocus()
                }
            }

            // Clicks pass through everything except the islands/pills
            mask: Region {
                Region { item: media }
                Region { item: clock }
                Region { item: control }
                Region { item: dash }
                Region { item: side }
                Region { item: popouts.panel }
                Region { item: dismiss }
                Region { item: wsDots }
            }

            Item {
                id: stage
                anchors.fill: parent

                // "Island" style: the three islands centered at the top, as before
                readonly property real islandsW: media.width + clock.width + control.width + Theme.gap * 2
                readonly property real startX: (width - islandsW) / 2

                // Dashboard open: a click anywhere else closes it (covers the whole window only while open)
                Item {
                    id: dismiss
                    z: -1
                    width: ((win.dashStyle && dash.mode === "open") || (win.sideStyle && popouts.expanded)) ? stage.width : 0
                    height: ((win.dashStyle && dash.mode === "open") || (win.sideStyle && popouts.expanded)) ? stage.height : 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: win.ctl.close()
                    }
                }

                // Music = launcher: without a player it is the circle that opens the launcher, with music it becomes the card.
                // In the classic bar it sits at the far left (and above the workspaces when it opens)
                MediaIsland {
                    id: media
                    visible: win.islands
                    z: 5
                    x: win.classic ? 14 : stage.startX
                    onLauncherRequested: {
                        UiState.launcherScreen = win.modelData.name
                        UiState.powerOpen = false
                        UiState.launcherOpen = !UiState.launcherOpen
                    }
                }

                Clock {
                    id: clock
                    // dashboard: the clock island only shows up for launcher, power, recording menu, toasts...
                    visible: win.islands || clock.special
                    attachedPanels: win.sideStyle
                    screenName: win.modelData.name
                    // classic: the clock is always at the center of the screen
                    x: (win.classic || win.dashStyle || win.sideStyle) ? (stage.width - clock.width) / 2 + (win.sideStyle ? side.width / 2 : 0) : media.x + media.width + Theme.gap
                    y: 0
                }

                // Attached Dashboard: the menus (launcher, power, themes...) come out of the edge with the same shape
                AttachedShape {
                    visible: win.attachedDash && clock.visible
                    z: -0.4
                    x: clock.x - fillet
                    y: clock.y
                    bodyWidth: clock.width
                    bodyHeight: clock.height
                    corner: clock.corner
                    edgeColor: clock.edgeColor
                }

                // Workspaces on the left, next to the launcher (classic bar only)
                WorkspaceDots {
                    id: wsDots
                    visible: win.classic
                    screenName: win.modelData.name
                    x: 14 + Theme.islandHeight + Theme.gap
                    y: 0
                }

                // Attached Dashboard: the shape (with the curves where it meets the edge) is drawn behind the island
                AttachedShape {
                    visible: win.attachedDash && dash.visible
                    z: -0.4
                    x: dash.x - fillet
                    y: dash.y
                    bodyWidth: dash.width
                    bodyHeight: dash.height
                    corner: dash.corner
                    edgeColor: dash.edgeColor
                    edgeWidth: dash.edgeWidth
                }

                DashIsland {
                    id: dash
                    visible: win.dashStyle && !clock.special
                    screenName: win.modelData.name
                    x: (stage.width - dash.width) / 2
                    y: 0
                }

                // ---- Vertical style: frame + bar + panels ----
                ScreenFrame {
                    id: frame
                    visible: win.sideStyle
                    z: -0.5
                    anchors.fill: parent
                    barW: side.width
                    edge: 8
                    radius: 22
                }

                SideRail {
                    id: side
                    visible: win.sideStyle
                    width: 46
                    height: parent.height
                    x: 0
                    y: 0
                    screenName: win.modelData.name
                    current: popouts.current
                    onRequest: (name, cy) => popouts.activate(name, cy)
                    onPeek: (name, cy) => popouts.hoverOpen(name, cy)
                    onUnpeek: popouts.hoverCancel()
                }

                Popouts {
                    id: popouts
                    visible: win.sideStyle
                    anchors.fill: parent
                    screenName: win.modelData.name
                    barW: side.width
                    edge: frame.edge
                    stageH: stage.height
                    railHovered: side.hovered
                }

                ControlIsland {
                    id: control
                    visible: win.islands
                    classic: win.classic
                    x: win.classic ? stage.width - 14 - control.width : clock.x + clock.width + Theme.gap
                    y: 0
                }
            }
        }
    }
}
