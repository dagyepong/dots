import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.services

// The polkit password prompt (see services/PolkitService.qml for what
// polkit is and the one-agent-per-session catch).
//
// While an app is asking for authentication, every screen gets a dimming
// scrim on the Overlay layer, and the card (PolkitDialog.qml) appears on
// ONE screen — whichever monitor Hyprland had focused when the request
// came in. It's decided once per prompt, so moving the mouse to another
// monitor mid-typing doesn't make the card jump.
//
// It's deliberately modal: the focused screen takes keyboard focus
// exclusively (so a password can never end up typed into a window
// underneath), and the scrims swallow clicks. Escape or Cancel gets you
// out. If the screen is locked the prompt simply waits behind the
// lockscreen — the session lock covers every other surface.
Scope {
    id: root

    readonly property string focusedName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    // Loader (not just `visible`) so the dialog — and the password field
    // in it — is created fresh for every prompt instead of hanging on to
    // the last one's text.
    Loader {
        active: PolkitService.active

        sourceComponent: Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property var modelData
                screen: modelData

                // Latched once, when this prompt's windows are created.
                // Falls back to the first screen if Hyprland's focused
                // monitor can't be matched to one.
                property bool isTarget: false
                Component.onCompleted: {
                    const names = Quickshell.screens.map(s => s.name)
                    const f = root.focusedName
                    isTarget = (f !== "" && names.includes(f))
                        ? modelData.name === f
                        : modelData === Quickshell.screens[0]
                }

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.namespace: "sekaipop-polkit"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: win.isTarget ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                // The dim. Navy at ~half strength, so it reads as "the
                // whole shell went quiet" rather than a black-out.
                Rectangle {
                    id: scrim
                    anchors.fill: parent
                    color: "#99555473"
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // Swallow clicks so nothing underneath is touched.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                    }
                }

                Loader {
                    anchors.centerIn: parent
                    active: win.isTarget
                    // This monitor's scale (scale.json / services/
                    // ShellScale.qml); the card grows around its centre.
                    scale: ShellScale.forScreen(win.screen)

                    sourceComponent: PolkitDialog {
                        message: PolkitService.message
                        prompt: PolkitService.prompt
                        passwordMode: PolkitService.passwordMode
                        interactionAvailable: PolkitService.interactionAvailable
                        failed: PolkitService.failed

                        onSubmitted: text => PolkitService.submit(text)
                        onCancelled: PolkitService.cancel()
                    }
                }
            }
        }
    }
}
