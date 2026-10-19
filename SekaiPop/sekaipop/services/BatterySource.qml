import Quickshell
import Quickshell.Services.UPower
import QtQuick

// The system side of the battery indicator. UPower is a Quickshell
// built-in (same family as the Mpris/SystemTray/Notifications services
// the rest of the shell already uses), so there's nothing extra to
// install for this — on a desktop with no battery, `available` just
// stays false and BatteryIndicator.qml hides itself.
Scope {
    id: root

    readonly property bool available: UPower.displayDevice.isLaptopBattery
    readonly property int percentage: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
    readonly property bool isCharging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool isPluggedIn: isCharging || UPower.displayDevice.state === UPowerDeviceState.PendingCharge
    readonly property bool isLow: available && percentage <= 20 && !isCharging

    // "1h 42m" / "38m" — whichever of timeToEmpty / timeToFull applies
    // right now. UPower reports both in seconds; 0 means "unknown yet"
    // (common right after plugging in or unplugging), so that shows
    // nothing rather than "0m".
    readonly property string timeRemaining: {
        const seconds = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty
        if (!seconds || seconds <= 0)
            return ""
        const h = Math.floor(seconds / 3600)
        const m = Math.round((seconds % 3600) / 60)
        return (h > 0 ? h + "h " : "") + m + "m"
    }

    readonly property string statusLabel: {
        if (!available) return ""
        if (percentage >= 100 && isPluggedIn) return "Fully charged"
        if (isCharging) return "Charging"
        if (isPluggedIn) return "Plugged in"
        return "On battery"
    }
}
