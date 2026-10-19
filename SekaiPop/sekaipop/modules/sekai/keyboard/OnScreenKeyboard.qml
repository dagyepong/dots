import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "KeyboardLayout.js" as KL

// The shell's own on-screen keyboard, in the style of the workspace pill bar:
// the housing is the bar's own look (navy outline, pale ring, hard shadow, the
// Dock's Pill construction) and every key is a workspace badge (KeyboardKey.qml).
//
// What a key does and what the modifiers do lives in KeyboardLayout.js; typing
// itself goes through services/KeyboardService.qml (wtype). This file is the
// window and the layout of the keys.
//
// The window is a layer-shell surface on the Overlay layer that NEVER takes the
// keyboard focus (WlrKeyboardFocus.None), so clicking a key does not pull focus
// away from the window being typed into. It sits at the bottom edge of the
// focused monitor, centred, and does not reserve screen space.
//
//   qs -c sekaipop ipc call keyboard toggle | show | hide
//
// One PanelWindow per screen, all built once and kept (the same way OSDPopup
// does it, so the slide-out can play); only the focused monitor's ever shows.
Variants {
    id: root

    // Geometry, in design pixels (the window is this times the monitor's scale).
    readonly property real keyH: KL.UNIT
    readonly property real rowPitch: KL.UNIT + Theme.shadowOffset + KL.GAP
    readonly property real pad: 18                       // keys to the housing's edge
    readonly property real rowsW: KL.rowsWidth()
    readonly property real rowsH: 5 * rowPitch - KL.GAP
    readonly property real housingW: rowsW + pad * 2
    readonly property real housingH: rowsH + pad * 2 + Theme.shadowOffset
    // Room above the housing for the close badge that hangs over its corner.
    readonly property real topRoom: 14
    readonly property real boardW: housingW
    readonly property real boardH: topRoom + housingH

    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        readonly property bool isTarget: KeyboardService.targetMonitorName !== ""
            ? modelData.name === KeyboardService.targetMonitorName
            : modelData === Quickshell.screens[0]
        readonly property bool wantsShow: win.isTarget && KeyboardService.open

        // 0 hidden .. 1 shown, animated here so hiding can play out.
        property real revealed: 0

        // Shift / Caps / Ctrl / Alt / Super (KeyboardLayout.js).
        property var kb: KL.initial()

        function press(key) {
            if (key.kind === "mod") {
                win.kb = KL.tapMod(win.kb, key.id)
                return
            }
            KeyboardService.send(KL.command(key, win.kb))
            win.kb = KL.afterKey(win.kb)
        }

        onWantsShowChanged: {
            showAnim.stop()
            hideAnim.stop()
            if (wantsShow)
                showAnim.restart()
            else
                hideAnim.restart()
        }

        // Nothing stays armed from one opening to the next.
        onVisibleChanged: if (!win.visible) win.kb = KL.initial()

        NumberAnimation {
            id: showAnim
            target: win
            property: "revealed"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: hideAnim
            target: win
            property: "revealed"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }

        visible: revealed > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "sekaipop-keyboard"
        WlrLayershell.layer: WlrLayer.Overlay
        // The whole point of a keyboard like this: never steal the focus.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property real uiScale: ShellScale.forScreen(win.screen)

        // Bottom edge, centred (no left / right anchor), clear of a bar that
        // is on the bottom.
        anchors.bottom: true
        margins.bottom: Math.round((14 + (BarPositionService.position === "bottom" ? BarPositionService.thickness : 0)) * win.uiScale)

        implicitWidth: Math.ceil(root.boardW * win.uiScale)
        implicitHeight: Math.ceil(root.boardH * win.uiScale)

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            Item {
                id: board
                width: root.boardW
                height: root.boardH
                opacity: win.revealed
                // Rises from the edge as it appears.
                y: (1 - win.revealed) * 22

                // The housing: the bar's own construction, the same as the
                // Dock's pill (Dock.qml): outline -> pale ring -> surface.
                Pill {
                    id: housing
                    x: 0
                    y: root.topRoom
                    width: root.housingW
                    height: root.housingH
                    cornerRadius: Theme.radiusOuter
                    ringWidth: Theme.borderWidth + Theme.outerRingWidth
                    ringColorTop: Theme.surfaceRing
                    ringColorBottom: Theme.surfaceRing
                    fillColor: Theme.surface
                }

                // The rows of keys, placed by hand (KeyboardLayout.js has each
                // key's x and width), so a row never reflows when a key lights.
                Item {
                    id: keys
                    x: housing.x + root.pad
                    y: housing.y + root.pad
                    width: root.rowsW
                    height: root.rowsH

                    Repeater {
                        model: KL.layout()

                        delegate: Item {
                            id: rowItem

                            required property var modelData
                            required property int index

                            y: rowItem.index * root.rowPitch
                            width: root.rowsW
                            height: root.keyH + Theme.shadowOffset

                            Repeater {
                                model: rowItem.modelData.keys

                                delegate: KeyboardKey {
                                    id: k

                                    required property var modelData

                                    readonly property int modLevel: k.modelData.kind === "mod"
                                        ? KL.modState(win.kb, k.modelData.id) : 0

                                    x: k.modelData.x
                                    width: k.modelData.width
                                    keyHeight: root.keyH

                                    label: KL.labelFor(k.modelData, win.kb)
                                    icon: k.modelData.icon
                                    labelSize: k.modelData.kind === "char" ? 16 : 12
                                    repeats: k.modelData.repeat

                                    active: k.modLevel > 0
                                    locked: k.modelData.id === "caps" ? k.modLevel > 0 : k.modLevel === 2

                                    // Letters, digits and symbols are the badges' cyan; the
                                    // working keys the theme's second colour; a lit modifier
                                    // takes one of the five workspace colours.
                                    fill: k.modLevel > 0
                                        ? KL.modColor(k.modelData.id)
                                        : (k.modelData.kind === "char" ? Theme.accentCyan : Theme.accentMint)

                                    onActivated: win.press(k.modelData)
                                }
                            }
                        }
                    }
                }

                // Close: a small pink badge hanging over the housing's top-right
                // corner, like a sticker.
                Item {
                    id: closeBadge
                    width: 34
                    height: 34 + Theme.shadowOffset
                    x: root.boardW - width - 22
                    y: 0

                    Pill {
                        anchors.fill: parent
                        cornerRadius: Theme.radiusBadge
                        ringWidth: 6
                        fillColor: KL.modColor("shift")
                        pressed: closeArea.pressed

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "keyboard_hide"
                            size: 18
                            weight: 600
                            color: Theme.colBorder
                        }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeyboardService.hide()
                    }
                }
            }
        }
    }
}
