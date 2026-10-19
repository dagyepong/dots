import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common.widgets

// The OSD popup itself: shown on whichever monitor was focused when
// OSDSource.show() was last called (OSDSource.targetMonitorName),
// centered just under the bar. Pops in and fades back out on its own
// (OSDSource's hideTimer) or as soon as the pointer touches it — same
// "get out of my way" courtesy end4's own OSD uses (see OSDSource.qml's
// header comment).
//
// One PanelWindow per screen, all created once at startup and kept
// alive for the life of the shell — a Loader gated on OSDSource.open would
// destroy the window the instant it closes, with no chance for the
// fade-out below to actually play. `revealed` is this window's own
// 0..1 reveal amount, animated locally, so hiding is a normal
// Behavior/animation rather than the window vanishing on the spot.
// Only the window matching targetMonitorName ever becomes visible; the
// rest just sit at revealed: 0 doing nothing.
Variants {
    id: root

    readonly property int gap: 14

    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        readonly property bool isTarget: modelData.name === OSDSource.targetMonitorName
        readonly property bool wantsShow: win.isTarget && OSDSource.open

        // 0 fully hidden .. 1 fully shown. Starts at 0 so a screen that
        // isn't the target right now (the common case — only one screen
        // is ever the target) never pops visible at all.
        property real revealed: 0

        onWantsShowChanged: {
            showAnim.stop()
            hideAnim.stop()
            if (wantsShow)
                showAnim.restart()
            else
                hideAnim.restart()
        }

        NumberAnimation {
            id: showAnim
            target: win
            property: "revealed"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: hideAnim
            target: win
            property: "revealed"
            to: 0
            duration: 220
            easing.type: Easing.InCubic
        }

        visible: revealed > 0.001
        color: "transparent"
        // Doesn't reserve screen space, like the Quick Panel.
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "sekaipop-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // This monitor's scale (scale.json / services/ShellScale.qml).
        // The pill is drawn in design pixels inside a ScaleHost, so the
        // window is its design size times the scale, and it sits just
        // inside the bar, in the middle of the screen edge the bar is on
        // (services/BarPositionService.qml), at the bar's scaled
        // thickness (Bar.qml).
        readonly property real uiScale: ShellScale.forScreen(win.screen)
        readonly property string barPosition: BarPositionService.position
        readonly property real barOffset: Math.round((BarPositionService.thickness + root.gap) * win.uiScale)

        anchors {
            top: win.barPosition === "top"
            bottom: win.barPosition === "bottom"
            left: win.barPosition === "left"
            right: win.barPosition === "right"
        }
        margins {
            top: win.barPosition === "top" ? win.barOffset : 0
            bottom: win.barPosition === "bottom" ? win.barOffset : 0
            left: win.barPosition === "left" ? win.barOffset : 0
            right: win.barPosition === "right" ? win.barOffset : 0
        }

        implicitWidth: Math.ceil(indicator.width * win.uiScale)
        implicitHeight: Math.ceil(indicator.height * win.uiScale)

        // Only takes the mouse while actually shown — a hidden window
        // with revealed: 0 is invisible anyway, but this keeps a
        // mid-fade window from eating hover events past its own fade.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: win.revealed > 0.001
            onEntered: OSDSource.hide()
        }

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            OSDIndicator {
                id: indicator
                kind: OSDSource.kind
                value: OSDSource.kind === "mic" ? OSDSource.micVolume
                    : OSDSource.kind === "brightness" ? OSDSource.brightness
                    : OSDSource.kind === "gamma" ? OSDSource.gamma
                    : OSDSource.speakerVolume
                muted: OSDSource.kind === "mic" ? OSDSource.micMuted : OSDSource.speakerMuted

                opacity: win.revealed
                // Grows out of the edge the bar is on (and goes back into it),
                // like the bar's popups do.
                scale: 0.88 + 0.12 * win.revealed
                transformOrigin: win.barPosition === "top" ? Item.Top
                    : (win.barPosition === "bottom" ? Item.Bottom
                    : (win.barPosition === "left" ? Item.Left : Item.Right))
            }
        }
    }
}
