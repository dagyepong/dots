import QtQuick
import Quickshell.Io

QtObject {
    id: brightnessManager

    property int brightness: 0
    property bool isAvailable: false
    property bool detected: false
    property bool hasSyncedOnce: false

    // Fired only on user-initiated changes (slider/wheel/arrow/hotkey-poll),
    // not on the initial startup sync. Used to arm the brightness panel's
    // auto-close timer.
    signal userChanged()

    function refresh() {
        getProcess.running = true
    }

    function setBrightness(percent) {
        let v = Math.max(0, Math.min(100, Math.round(percent)))
        if (v === brightness) return
        brightness = v
        setProcess.payload = String(v) + "%"
        setProcess.running = true
        userChanged()
    }

    function bump(delta) {
        setBrightness(brightness + delta)
    }

    property Process detectProcess: Process {
        running: true
        command: ["bash", "-c", "command -v brightnessctl >/dev/null 2>&1 && [ -n \"$(ls /sys/class/backlight/ 2>/dev/null)\" ] && echo yes || echo no"]
        property string buf: ""
        stdout: SplitParser { onRead: data => detectProcess.buf += data }
        onExited: (exitCode) => {
            let ok = detectProcess.buf.trim() === "yes"
            brightnessManager.isAvailable = ok
            brightnessManager.detected = true
            detectProcess.buf = ""
            if (ok) brightnessManager.refresh()
        }
    }

    property Process getProcess: Process {
        running: false
        command: ["bash", "-c", "echo $(($(brightnessctl --class backlight get) * 100 / $(brightnessctl --class backlight max)))"]
        property string buf: ""
        stdout: SplitParser { onRead: data => getProcess.buf += data }
        onExited: (exitCode) => {
            let oldValue = brightnessManager.brightness
            if (exitCode === 0) {
                let v = parseInt(getProcess.buf.trim())
                if (!isNaN(v)) brightnessManager.brightness = v
            }
            let alreadySynced = brightnessManager.hasSyncedOnce
            brightnessManager.hasSyncedOnce = true
            // External change (e.g. hardware brightness key) caught by poll
            // counts as a user action — but suppress the initial startup sync.
            if (alreadySynced && oldValue !== brightnessManager.brightness) {
                brightnessManager.userChanged()
            }
            getProcess.buf = ""
        }
    }

    property Process setProcess: Process {
        running: false
        property string payload: ""
        command: ["brightnessctl", "--class", "backlight", "set", payload]
    }

    property Timer pollTimer: Timer {
        interval: 2000
        running: brightnessManager.isAvailable
        repeat: true
        onTriggered: brightnessManager.refresh()
    }
}
