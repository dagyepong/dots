pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    readonly property WifiDevice wifiDevice: {
        for (const dev of Networking.devices.values) {
            if (dev.type === DeviceType.Wifi) return dev
        }
        return null
    }

    property bool wifiEnabled: Networking.wifiEnabled
    property bool scanning: wifiDevice ? wifiDevice.scannerEnabled : false

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled
    }

    function scan() {
        if (wifiDevice) wifiDevice.scannerEnabled = true
    }

    function stopScan() {
        if (wifiDevice) wifiDevice.scannerEnabled = false
    }

    readonly property var networks: wifiDevice ? wifiDevice.networks.values : []
}
