pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    property bool bluetoothEnabled: adapter ? adapter.enabled : false
    property bool scanning: adapter ? adapter.discovering : false

    function setBluetoothEnabled(enabled) {
        if (adapter) adapter.enabled = enabled
        scan()
    }

    function scan() {
        if (adapter) adapter.discovering = true
    }

    function stopScan() {
        if (adapter) adapter.discovering = false
    }

    readonly property var devices: adapter ? adapter.devices.values : []
}
