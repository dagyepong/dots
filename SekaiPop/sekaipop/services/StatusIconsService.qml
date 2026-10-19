pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.common

// What the bar's status pill (StatusPill.qml) shows: Wi-Fi / Ethernet,
// Bluetooth and the speaker, as an icon each plus a line of detail for the
// hover tag. It looks only while some bar shows the pill (`wanted`, below): not
// with the pill switched off, not in Game Mode, not with the bar hidden. (The
// Quick Panel's own copy of this only polls while the panel is open.)
//
//   Wi-Fi / Ethernet and Bluetooth   a light look every few seconds
//                                    (scripts/system/status-icons.sh: nmcli, bluetoothctl)
//   speaker                          read straight from PipeWire (no polling)
//
// For each of the three:
//   <x>Shown   false when there is nothing to show (no Bluetooth adapter, no
//              NetworkManager, no audio output): the icon is left out.
//   <x>Icon    the Material Symbols name
//   <x>State   "on" | "idle" | "off": the pill draws idle a bit dimmer and
//              off dimmer still
//   <x>Detail  one line, "Wi-Fi: HomeNet"
//
//   qs -c sekaipop ipc call statusicons get
//   qs -c sekaipop ipc call statusicons refresh
Singleton {
    id: root

    // ===== Wi-Fi / Ethernet =====
    property bool networkKnown: false     // nmcli answered at least once
    property bool wifiRadio: false
    property string wifiName: ""
    property string ethernetName: ""

    readonly property bool networkShown: root.networkKnown
    readonly property string networkIcon: {
        if (root.wifiName !== "")
            return "wifi"
        if (root.ethernetName !== "")
            return "settings_ethernet"
        return root.wifiRadio ? "wifi_find" : "wifi_off"
    }
    readonly property string networkState: {
        if (root.wifiName !== "" || root.ethernetName !== "")
            return "on"
        return root.wifiRadio ? "idle" : "off"
    }
    readonly property string networkDetail: {
        const parts = []
        if (root.wifiName !== "")
            parts.push("Wi-Fi: " + root.wifiName)
        if (root.ethernetName !== "")
            parts.push("Ethernet: " + root.ethernetName)
        if (parts.length > 0)
            return parts.join("   ·   ")
        return root.wifiRadio ? "Wi-Fi: not connected" : "Wi-Fi: off"
    }

    // ===== Bluetooth =====
    property bool bluetoothShown: false   // there is an adapter
    property bool bluetoothOn: false
    property string bluetoothDevice: ""   // first connected device

    // Off, on with nothing connected, and a device connected each have their own.
    readonly property string bluetoothIcon: !root.bluetoothOn ? "bluetooth_disabled"
        : (root.bluetoothDevice !== "" ? "bluetooth_connected" : "bluetooth")
    readonly property string bluetoothState: !root.bluetoothOn ? "off"
        : (root.bluetoothDevice !== "" ? "on" : "idle")
    readonly property string bluetoothDetail: !root.bluetoothOn ? "Bluetooth: off"
        : (root.bluetoothDevice !== "" ? "Bluetooth: " + root.bluetoothDevice
                                       : "Bluetooth: on, nothing connected")

    // ===== Speaker =====
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink].filter(n => n)
    }
    readonly property var sinkAudio: Pipewire.defaultAudioSink?.audio ?? null

    readonly property bool speakerShown: root.sinkAudio !== null
    readonly property bool speakerMuted: root.sinkAudio ? root.sinkAudio.muted : false
    readonly property int speakerPercent: root.sinkAudio ? Math.round(root.sinkAudio.volume * 100) : 0

    // The same steps as the volume OSD: muted / silent, low, then normal.
    readonly property string speakerIcon: root.speakerMuted || root.speakerPercent <= 0 ? "volume_off"
        : (root.speakerPercent < 34 ? "volume_down" : "volume_up")
    readonly property string speakerState: root.speakerMuted || root.speakerPercent <= 0 ? "off" : "on"
    readonly property string speakerDetail: root.speakerMuted ? "Speaker: muted"
        : "Speaker: " + root.speakerPercent + "%"

    // ===== everything on one line for the hover tag =====
    readonly property string detail: {
        const lines = []
        if (root.networkShown)
            lines.push(root.networkDetail)
        if (root.bluetoothShown)
            lines.push(root.bluetoothDetail)
        if (root.speakerShown)
            lines.push(root.speakerDetail)
        return lines.join("\n")
    }

    // ===== who wants it =====
    // Each bar that shows the status pill adds one (Bar.qml, `statusDemand`) and takes it
    // back when the pill goes away (switched off, Game Mode, the bar rebuilt or removed).
    // Nothing is looked up while nobody is counted; the first one in looks at once.
    property int watchers: 0
    readonly property bool wanted: root.watchers > 0

    function watch(delta) {
        root.watchers = Math.max(0, root.watchers + delta)
    }

    // ===== the look =====
    readonly property string script: Directories.script("system/status-icons.sh")

    function refresh() {
        if (!looker.running)
            looker.exec(["sh", root.script])
    }

    Process {
        id: looker
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0)
                        kv[line.slice(0, i)] = line.slice(i + 1)
                }
                const wifi = (kv.wifi || "").trim()
                root.wifiRadio = wifi === "enabled"
                root.wifiName = kv.ssid || ""
                root.ethernetName = kv.eth || ""
                // nmcli prints the radio state whenever NetworkManager runs.
                root.networkKnown = wifi !== "" || root.ethernetName !== ""

                const bt = (kv.bt || "").trim()
                root.bluetoothShown = bt !== ""
                root.bluetoothOn = bt === "yes"
                root.bluetoothDevice = root.bluetoothOn ? (kv.btdev || "") : ""
            }
        }
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "statusicons"

        function get(): string {
            // With no pill on a bar nothing keeps these fresh: look now, so the next call is right.
            if (!root.wanted)
                root.refresh()
            return root.detail
        }

        function refresh(): void {
            root.refresh()
        }
    }
}
