import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Lock and screen off after inactivity (Settings > Wallpaper, lock & idle). Needs ext-idle-notify on the compositor.
Scope {
    IdleMonitor {
        enabled: Settings.lockMin > 0
        timeout: Settings.lockMin * 60
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"])
    }

    IdleMonitor {
        id: screenOff
        enabled: Settings.screenOffMin > 0
        timeout: Settings.screenOffMin * 60
        onIsIdleChanged: {
            if (Compositor.isHyprland)
                Quickshell.execDetached(["hyprctl", "dispatch", "dpms", isIdle ? "off" : "on"])
            else if (Compositor.isNiri && isIdle)
                Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
        }
    }
}
