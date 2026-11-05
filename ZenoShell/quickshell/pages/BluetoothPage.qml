import QtQuick
import Quickshell.Bluetooth
import qs.theme
import qs.widgets

Item {
    id: root

    signal back()
    property bool embedded: false      // inside the Settings window: no back arrow

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false

    // Paired: connected ones first
    readonly property var pairedList: {
        const v = Bluetooth.devices.values
        const out = []
        for (let i = 0; i < v.length; i++) if (v[i].paired && v[i].connected) out.push(v[i])
        for (let i = 0; i < v.length; i++) if (v[i].paired && !v[i].connected) out.push(v[i])
        return out
    }

    // Found but not yet paired
    readonly property var nearbyList: {
        const v = Bluetooth.devices.values
        const out = []
        for (let i = 0; i < v.length; i++) if (!v[i].paired && v[i].name !== "") out.push(v[i])
        return out
    }

    width: 360
    height: 440

    // The scan runs only while the page is visible
    function syncDiscovery() {
        if (adapter) adapter.discovering = visible && powered
    }
    onVisibleChanged: syncDiscovery()
    onPoweredChanged: syncDiscovery()

    PageHeader {
        showBack: !root.embedded
        x: 14; y: 14
        width: root.width - 28
        title: "Bluetooth"
        showSwitch: true
        checked: root.powered
        onBack: root.back()
        onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
    }

    Text {
        anchors.centerIn: parent
        visible: !root.powered
        text: root.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Flickable {
        x: 14; y: 54
        width: root.width - 28
        height: root.height - 54 - 14
        contentHeight: col.implicitHeight
        clip: true
        visible: root.powered
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 6

            Text {
                x: 4
                text: "My devices"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Repeater {
                model: root.pairedList

                delegate: ListRow {
                    required property var modelData

                    width: col.width
                    icon: "bluetooth"
                    title: modelData.name
                    subtitle: modelData.connected
                              ? "Connected" + (modelData.batteryAvailable
                                               ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                              : "Paired"
                    trailing: modelData.connected ? "Disconnect" : "Connect"
                    active: modelData.connected
                    onClicked: modelData.connected = !modelData.connected
                }
            }

            Text {
                x: 4
                visible: root.pairedList.length === 0
                text: "No paired devices"
                color: Theme.muted
                opacity: 0.6
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Item {
                width: col.width
                height: 22

                Text {
                    x: 4
                    anchors.bottom: parent.bottom
                    text: "Available"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.bottom: parent.bottom
                    visible: root.adapter ? root.adapter.discovering : false
                    text: "Scanning"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }

            Repeater {
                model: root.nearbyList

                delegate: ListRow {
                    required property var modelData

                    width: col.width
                    icon: "bluetooth"
                    title: modelData.name
                    subtitle: "Not paired"
                    trailing: "Pair"
                    onClicked: modelData.pair()
                }
            }

            Text {
                x: 4
                visible: root.nearbyList.length === 0
                text: "No devices found"
                color: Theme.muted
                opacity: 0.6
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
