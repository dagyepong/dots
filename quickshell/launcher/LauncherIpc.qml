import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Scope {
    id: root

    // Opens the launcher on the monitor that has focus in Hyprland
    function openOnFocusedScreen() {
        UiState.launcherScreen = Compositor.focusedMonitor
        UiState.powerOpen = false
        UiState.launcherOpen = true
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (UiState.launcherOpen) UiState.launcherOpen = false
            else root.openOnFocusedScreen()
        }

        function open(): void { root.openOnFocusedScreen() }

        function close(): void { UiState.launcherOpen = false }
    }
}
