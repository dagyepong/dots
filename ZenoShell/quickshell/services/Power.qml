pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    function open() {
        UiState.powerScreen = Compositor.focusedMonitor
        UiState.launcherOpen = false
        UiState.wallpaperOpen = false
        UiState.powerOpen = true
    }

    function close() { UiState.powerOpen = false }

    function toggle() {
        if (UiState.powerOpen) close()
        else open()
    }

    function run(action) {
        close()

        if (action === "lock") {
            UiState.lockTest = false
            UiState.locked = true
        } else if (action === "logout") {
            Compositor.logout()
        } else if (action === "suspend") {
            Quickshell.execDetached(["systemctl", "suspend"])
        } else if (action === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"])
        } else if (action === "shutdown") {
            Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }
}
