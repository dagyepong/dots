pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root
    
    readonly property var adapter: Bluetooth.defaultAdapter
    
    readonly property bool powered: adapter ? (adapter.enabled === true) : false
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevices: {
        if (!devices || devices.length === 0) return []
        return devices.filter(d => d && d.connected)
    }
    readonly property bool connected: connectedDevices.length > 0
    readonly property string deviceName: connected && connectedDevices[0]
        ? (connectedDevices[0].name || "Device")
        : ""
    readonly property int deviceCount: connectedDevices.length
    
    Component.onCompleted: {
        console.log("Bluetooth Service initialized")
        console.log("Adapter exists:", adapter !== null)
        console.log("Bluetooth object:", Bluetooth)
        if (adapter) {
            console.log("Adapter.enabled:", adapter.enabled)
        }
    }
    
    Connections {
        target: adapter
        function onEnabledChanged() {
            console.log("Adapter.enabled changed to:", adapter.enabled)
        }
    }
    
    onAdapterChanged: {
        console.log("Adapter changed:", adapter)
    }
    
    function togglePower() {
        if (!adapter) {
            console.warn("Cannot toggle: no Bluetooth adapter available")
            return
        }
        
        if (adapter.enabled === undefined) {
            console.warn("Cannot toggle: adapter.enabled is undefined")
            return
        }
        
        adapter.enabled = !adapter.enabled
    }
}