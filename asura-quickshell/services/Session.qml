pragma Singleton
import "../core"
import "../services"
import Quickshell
import QtQuick

Singleton {
    id: root

    function lock() {
        if (Config.options.lock.useHyprlock) {
            Quickshell.execDetached(["bash", "-c", "pidof hyprlock || hyprlock"]);
            return;
        }
        GlobalStates.screenLocked = true;
    }

    function suspend() {
        Quickshell.execDetached(["bash", "-c", "systemctl suspend || loginctl suspend"]);
    }

    function logout() {
        Quickshell.execDetached(["bash", "-c", "if command -v hyprshutdown >/dev/null 2>&1; then exec hyprshutdown -t 'Logging out...'; fi; hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit"]);
    }

    function launchTaskManager() {
        Quickshell.execDetached(["bash", "-c", "missioncenter || gnome-system-monitor || plasma-systemmonitor"]);
    }

    function hibernate() {
        Quickshell.execDetached(["bash", "-c", "systemctl hibernate || loginctl hibernate"]);
    }

    function poweroff() {
        Quickshell.execDetached(["bash", "-c", "if command -v hyprshutdown >/dev/null 2>&1; then exec hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff || loginctl poweroff'; fi; systemctl poweroff || loginctl poweroff"]);
    }

    function reboot() {
        Quickshell.execDetached(["bash", "-c", "if command -v hyprshutdown >/dev/null 2>&1; then exec hyprshutdown -t 'Restarting...' --post-cmd 'systemctl reboot || loginctl reboot'; fi; systemctl reboot || loginctl reboot"]);
    }

    function rebootToFirmware() {
        Quickshell.execDetached(["bash", "-c", "systemctl reboot --firmware-setup || loginctl reboot --firmware-setup"]);
    }
}
