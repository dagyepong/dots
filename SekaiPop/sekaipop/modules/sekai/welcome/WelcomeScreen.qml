import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.services

// The welcome screen's windows (the page itself is WelcomePage.qml; when it
// shows up is WelcomeService.qml).
//
// Same shape as the polkit prompt (PolkitPrompt.qml): every screen gets a
// full-screen window on the Overlay layer so the desktop is covered
// everywhere, but only ONE screen shows the slides and takes the keyboard
// exclusively: whichever monitor Hyprland had focused when the screen opened,
// decided once, so moving the mouse to another monitor can't make the show
// jump. The others show just the page and the faint logo.
//
// The Loader is the whole "avoid unnecessary work" story, as in Serpantinum's
// first-launch Loader: until the service says `active`, none of this exists.
// When it ends the windows, the animations and the textures are all freed.
Scope {
    id: root

    readonly property string focusedName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    Loader {
        active: WelcomeService.active

        sourceComponent: Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property var modelData
                screen: modelData

                // Latched once, when this showing's windows are created. Falls
                // back to the first screen if Hyprland's focused monitor can't
                // be matched to one.
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

                WlrLayershell.namespace: "sekaipop-welcome"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: win.isTarget ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                WelcomePage {
                    anchors.fill: parent
                    showContent: win.isTarget
                    closing: WelcomeService.closing
                    wallpaper: WallpaperService.imagePath
                    onLeaveRequested: skipped => {
                        // a skip or a finish both count as "seen"
                        WelcomeService.beginClose()
                    }
                    // Only the screen with the slides decides when it is over,
                    // so the other windows can't pull the rug from under it.
                    onExited: if (win.isTarget) WelcomeService.finish()
                }
            }
        }
    }
}
