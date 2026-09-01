pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "Singletons"

/**
 * Bluetooth drill-in for the link surface: back chevron, scan with 25s
 * auto-stop, adapter toggle, live device list. Known devices use the
 * Quickshell connect/disconnect calls; unpaired devices run a bluetoothctl
 * pair-trust-connect flow with an inline ember while running and a transient
 * failure line.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    signal back()

    readonly property var adapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var adapterDevices: (adapter && adapter.devices) ? adapter.devices.values : []
    readonly property var globalDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
    property var scanDevices: []
    readonly property var devices: {
        var out = [];
        var seen = ({});
        for (var i = 0; i < adapterDevices.length; i++)
            addDevice(out, seen, adapterDevices[i]);
        for (var j = 0; j < globalDevices.length; j++)
            addDevice(out, seen, globalDevices[j]);
        for (var k = 0; k < scanDevices.length; k++)
            addDevice(out, seen, scanDevices[k]);
        return out;
    }

    /**
     * BlueZ hands the cache out in arbitrary order; sort connected first,
     * then paired, then named devices, nameless MACs last so a discovery scan
     * doesn't churn the useful rows around.
     */
    readonly property var devicesSorted: devices.slice().sort(function(a, b) {
        function rank(d) {
            if (!d) return 3;
            if (d.connected) return 0;
            if (d.paired) return 1;
            return (d.name && d.name.length) ? 2 : 3;
        }
        var r = rank(a) - rank(b);
        if (r !== 0) return r;
        return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
    })
    readonly property bool discovering: scanProc.running

    property string pairingAddress: ""
    property string failedAddress: ""
    property int navIndex: 0
    property string actionFocus: "row"
    property string focusTarget: "list"

    readonly property bool listFocused: focusTarget === "list"
    readonly property var focusTargets: {
        var targets = ["back"];
        if (adapter && adapter.enabled === true)
            targets.push("scan");
        targets.push("toggle");
        if (devicesSorted.length > 0)
            targets.push("list");
        return targets;
    }

    /**
     * Address of the known device whose inline confirm row (disconnect or
     * connect, plus forget) is open, mirroring the wifi drill-in's expanded
     * SSID.
     */
    property string expandedAddress: ""

    implicitHeight: listFrame.y + listFrame.height

    function addressOf(d) {
        return (d && d.address) ? String(d.address) : "";
    }

    function addDevice(out, seen, d) {
        if (!d)
            return;
        var addr = addressOf(d);
        var key = addr.length ? addr : String((d.deviceName || d.name || "") + "|" + out.length);
        if (seen[key])
            return;
        seen[key] = true;
        out.push(d);
    }

    function stripAnsi(text) {
        return String(text).replace(/\u001b\[[0-9;]*m/g, "").trim();
    }

    function rememberScannedDevice(addr, name) {
        if (!addr || !addr.length)
            return;

        var arr = scanDevices.slice();
        var cleanName = (name && name.length) ? name : "";
        if (cleanName.toUpperCase() === addr || cleanName.toUpperCase() === addr.replace(/:/g, "-"))
            cleanName = "";
        var label = cleanName.length ? cleanName : addr;
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].address === addr) {
                if (cleanName.length && arr[i].name !== cleanName)
                    arr[i] = { address: addr, name: cleanName, deviceName: label, connected: false, paired: false, scanned: true };
                scanDevices = arr;
                return;
            }
        }
        arr.push({ address: addr, name: cleanName, deviceName: label, connected: false, paired: false, scanned: true });
        scanDevices = arr;
    }

    function ingestScanLine(line) {
        var clean = stripAnsi(line);
        var m = clean.match(/\[NEW\] Device ([0-9A-Fa-f:]{17})(?: (.*))?$/);
        if (m) {
            rememberScannedDevice(m[1].toUpperCase(), (m[2] || "").trim());
            return;
        }

        m = clean.match(/\[CHG\] Device ([0-9A-Fa-f:]{17}) (Name|Alias): (.*)$/);
        if (m)
            rememberScannedDevice(m[1].toUpperCase(), (m[3] || "").trim());
    }

    function metaFor(d) {
        if (!d) return "";
        var parts = [];
        if (d.connected) parts.push("connected");
        else if (d.paired) parts.push("paired");
        else if (d.scanned) parts.push("discovered");
        if (d.state !== undefined && typeof BluetoothDeviceState !== "undefined") {
            var st = BluetoothDeviceState.toString(d.state);
            if (st && st.length > 0 && parts.indexOf(st.toLowerCase()) === -1) parts.push(st.toLowerCase());
        }
        return parts.join(" · ");
    }

    function batteryLevel(d) {
        if (!d || d.battery === undefined || d.battery === null) return -1;
        var b = d.battery;
        if (b <= 0) return -1;
        if (b <= 1) b = b * 100;
        return Math.round(b);
    }

    /**
     * Click dispatch for a device row. A connected or paired device toggles
     * the inline confirm row rather than acting at once; an unpaired device
     * runs the bluetoothctl pair-trust-connect flow.
     */
    function activateDevice(d) {
        if (!d)
            return;
        if (d.connected || d.paired) {
            var addr = d.address || "";
            expandedAddress = (addr.length && expandedAddress === addr) ? "" : addr;
            return;
        }
        pairDevice(d);
    }

    function connectDevice(d) {
        expandedAddress = "";
        if (d && typeof d.connect === "function")
            d.connect();
    }

    function disconnectDevice(d) {
        expandedAddress = "";
        if (d && typeof d.disconnect === "function")
            d.disconnect();
    }

    /**
     * Unpairs through the Quickshell device object, the same layer the
     * connect and disconnect calls use; BlueZ drops the bond and the row
     * falls back to its Pair chip.
     */
    function forgetDevice(d) {
        expandedAddress = "";
        if (d && typeof d.forget === "function")
            d.forget();
    }

    function currentDevice() {
        return navIndex >= 0 && navIndex < devicesSorted.length ? devicesSorted[navIndex] : null;
    }

    function currentActionNames() {
        var d = currentDevice();
        if (!d)
            return [];

        var names = ["row"];
        if (expandedAddress === addressOf(d) && (d.connected || d.paired)) {
            names.push("primary");
            names.push("forget");
        }
        return names;
    }

    function normalizeNav() {
        if (devicesSorted.length === 0) {
            navIndex = -1;
            actionFocus = "row";
            return;
        }
        if (navIndex < 0)
            navIndex = 0;
        else if (navIndex >= devicesSorted.length)
            navIndex = devicesSorted.length - 1;

        var names = currentActionNames();
        if (names.indexOf(actionFocus) < 0)
            actionFocus = "row";
    }

    function normalizeFocusTarget() {
        if (focusTargets.length === 0) {
            focusTarget = "";
            return;
        }
        if (focusTargets.indexOf(focusTarget) >= 0)
            return;
        var listIdx = focusTargets.indexOf("list");
        var scanIdx = focusTargets.indexOf("scan");
        focusTarget = listIdx >= 0 ? "list"
            : scanIdx >= 0 ? "scan"
            : focusTargets[focusTargets.length - 1];
    }

    function headerFocused(name) {
        return active && focusTarget === name;
    }

    function scrollToNav() {
        if (navIndex < 0)
            return;
        var maxY = Math.max(0, devFlick.contentHeight - devFlick.height);
        if (maxY <= 0) {
            devFlick.contentY = 0;
            return;
        }
        devFlick.contentY = Math.max(0, Math.min(maxY, navIndex * 42 * s - devFlick.height / 2 + 21 * s));
    }

    function moveNav(dir) {
        if (devicesSorted.length === 0)
            return false;
        if (focusTarget !== "list") {
            focusTarget = "list";
            normalizeNav();
            scrollToNav();
            return true;
        }
        normalizeNav();
        navIndex = (navIndex + dir + devicesSorted.length) % devicesSorted.length;
        actionFocus = "row";
        scrollToNav();
        return true;
    }

    function moveAction(dir) {
        if (focusTarget !== "list")
            return moveTab(dir);
        normalizeNav();
        var names = currentActionNames();
        if (names.length <= 1)
            return false;
        var idx = names.indexOf(actionFocus);
        if (idx < 0)
            idx = 0;
        actionFocus = names[(idx + dir + names.length) % names.length];
        return true;
    }

    function moveTab(dir) {
        if (focusTargets.length === 0)
            return false;
        normalizeFocusTarget();
        var idx = focusTargets.indexOf(focusTarget);
        if (idx < 0)
            idx = 0;
        focusTarget = focusTargets[(idx + dir + focusTargets.length) % focusTargets.length];
        if (focusTarget === "list") {
            normalizeNav();
            scrollToNav();
        }
        return true;
    }

    function toggleAdapter() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function activateFocused() {
        if (focusTarget === "back") {
            back();
            return true;
        }
        if (focusTarget === "scan") {
            if (discovering)
                stopScan();
            else
                startScan();
            return true;
        }
        if (focusTarget === "toggle") {
            toggleAdapter();
            return true;
        }

        normalizeNav();
        var d = currentDevice();
        if (!d)
            return false;

        if (actionFocus === "primary") {
            if (d.connected)
                disconnectDevice(d);
            else
                connectDevice(d);
            return true;
        }
        if (actionFocus === "forget") {
            forgetDevice(d);
            return true;
        }
        activateDevice(d);
        return true;
    }

    function keyPress(key, isAutoRepeat) {
        if (key === Qt.Key_Tab)
            return moveTab(1);
        if (key === Qt.Key_Backtab)
            return moveTab(-1);
        if (key === Qt.Key_K || key === Qt.Key_Up)
            return moveNav(-1);
        if (key === Qt.Key_J || key === Qt.Key_Down)
            return moveNav(1);
        if (key === Qt.Key_H || key === Qt.Key_Left)
            return moveAction(-1);
        if (key === Qt.Key_L || key === Qt.Key_Right)
            return moveAction(1);
        if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
            return activateFocused();
        return false;
    }

    function pairDevice(d) {
        if (!d || !d.address || pairProc.running)
            return;
        pairingAddress = d.address;
        failedAddress = "";
        pairProc.command = ["sh", "-c",
            'timeout 30 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 30 bluetoothctl connect "$1"',
            "sh", d.address];
        pairProc.running = true;
    }

    function startScan() {
        if (!adapter || adapter.enabled !== true)
            return;

        scanDevices = [];
        scanProc.command = ["bluetoothctl", "--timeout", "25", "scan", "on"];
        scanProc.running = true;
        scanTimer.restart();
    }

    function stopScan() {
        scanTimer.stop();
        if (scanProc.running)
            scanProc.running = false;
    }

    onActiveChanged: {
        if (active) {
            normalizeFocusTarget();
            normalizeNav();
            scrollToNav();
        } else {
            stopScan();
            focusTarget = "list";
            expandedAddress = "";
        }
    }
    onDevicesSortedChanged: {
        normalizeFocusTarget();
        normalizeNav();
    }
    onExpandedAddressChanged: normalizeNav()

    Connections {
        target: root.adapter
        function onEnabledChanged() {
            root.normalizeFocusTarget();
            root.normalizeNav();
        }
    }

    Timer {
        id: scanTimer
        interval: 25000
        repeat: false
        onTriggered: root.stopScan()
    }

    Timer {
        id: failTimer
        interval: 4000
        repeat: false
        onTriggered: root.failedAddress = ""
    }

    Process {
        id: pairProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            var addr = root.pairingAddress;
            root.pairingAddress = "";
            if (exitCode !== 0) {
                root.failedAddress = addr;
                failTimer.restart();
            }
        }
    }

    Process {
        id: scanProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.ingestScanLine(data); }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.ingestScanLine(data); }
        }
        onExited: {
            scanTimer.stop();
        }
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 17 * root.s
                height: 17 * root.s

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    radius: 6 * root.s
                    color: backArea.containsMouse || root.headerFocused("back") ? Theme.frameBg : "transparent"
                    border.width: root.headerFocused("back") ? 1 : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.85)
                }

                GlyphIcon {
                    anchors.fill: parent
                    name: "chevron-left"
                    color: backArea.containsMouse || root.headerFocused("back") ? Theme.cream : Theme.iconDim
                    stroke: 1.8
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "BLUETOOTH"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.adapter ? root.adapter.enabled === true : false
                width: scanLabel.implicitWidth + 12 * root.s
                height: 20 * root.s
                radius: 6 * root.s
                color: scanArea.containsMouse || root.headerFocused("scan") ? Theme.frameBg : "transparent"
                border.width: root.headerFocused("scan") ? 1 : 0
                border.color: Qt.alpha(Theme.vermLit, 0.85)

                Text {
                    id: scanLabel
                    anchors.centerIn: parent
                    text: root.discovering ? "Scanning…" : "Scan"
                    color: root.discovering ? Theme.vermLit : (scanArea.containsMouse || root.headerFocused("scan") ? Theme.cream : Theme.dim)
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: scanArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.discovering)
                            root.stopScan();
                        else
                            root.startScan();
                    }
                }
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.adapter ? root.adapter.enabled === true : false
                focused: root.headerFocused("toggle")
                onToggled: root.toggleAdapter()
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Item {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.devices.length > 0 ? Math.min(devCol.implicitHeight, 200 * root.s) : 24 * root.s
        readonly property bool scrollable: root.devices.length > 0 && devCol.implicitHeight > height + 1

        Text {
            visible: root.devices.length === 0
            anchors.centerIn: parent
            text: root.discovering ? "Scanning…" : "No devices found"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
        }

        Flickable {
            id: devFlick
            visible: root.devices.length > 0
            anchors.fill: parent
            contentHeight: devCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: devCol
                width: devFlick.width - (listFrame.scrollable ? 8 * root.s : 0)
                spacing: 2 * root.s

                Repeater {
                    model: root.devicesSorted

                    Column {
                        id: devItem
                        required property int index
                        required property var modelData
                        readonly property bool isConnected: modelData ? modelData.connected === true : false
                        readonly property bool isPaired: modelData ? modelData.paired === true : false
                        readonly property string addr: (modelData && modelData.address) ? modelData.address : ""
                        readonly property bool pairing: addr.length > 0 && root.pairingAddress === addr
                        readonly property bool failed: addr.length > 0 && root.failedAddress === addr
                        readonly property bool busy: (modelData && typeof BluetoothDeviceState !== "undefined")
                            ? (modelData.state === BluetoothDeviceState.Connecting
                                || modelData.state === BluetoothDeviceState.Disconnecting)
                            : false
                        readonly property bool confirming: addr.length > 0 && root.expandedAddress === addr
                        readonly property int battery: root.batteryLevel(modelData)
                        readonly property bool rowKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "row"
                        readonly property bool primaryKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "primary"
                        readonly property bool forgetKeyFocus: root.listFocused && root.navIndex === index && root.actionFocus === "forget"
                        width: devCol.width
                        spacing: 2 * root.s

                        Rectangle {
                            width: parent.width
                            height: 38 * root.s
                            radius: 9 * root.s
                            color: rowHover.hovered || devItem.rowKeyFocus ? Theme.frameBg : "transparent"
                            border.width: devItem.rowKeyFocus ? 1 : 0
                            border.color: Qt.alpha(Theme.vermLit, 0.78)

                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateDevice(devItem.modelData)
                            }

                            Rectangle {
                                id: devTile
                                anchors.left: parent.left
                                anchors.leftMargin: 6 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26 * root.s
                                height: 26 * root.s
                                radius: 8 * root.s
                                color: Theme.tileBg
                                border.width: 1
                                border.color: Theme.border

                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    name: "bluetooth"
                                    color: devItem.isConnected ? Theme.vermLit : Theme.iconDim
                                    stroke: 1.7
                                }
                            }

                            Column {
                                anchors.left: devTile.right
                                anchors.leftMargin: 10 * root.s
                                anchors.right: devRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1 * root.s

                                Text {
                                    width: parent.width
                                    text: devItem.modelData ? (devItem.modelData.deviceName || devItem.modelData.name || "Unknown") : "Unknown"
                                    color: devItem.isConnected ? Theme.cream : Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 11.5 * root.s
                                    font.weight: devItem.isConnected ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: root.metaFor(devItem.modelData)
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9.5 * root.s
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                id: devRight
                                anchors.right: parent.right
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: devItem.pairing || devItem.busy
                                    width: 4 * root.s
                                    height: 4 * root.s
                                    radius: width / 2
                                    color: Theme.flameGlow

                                    SequentialAnimation on opacity {
                                        running: devItem.pairing || devItem.busy
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                    }
                                }

                                Filament {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: devItem.isConnected && devItem.battery >= 0
                                    s: root.s
                                    kind: "battery"
                                    level: Math.max(0, devItem.battery) / 100
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !devItem.isPaired && !devItem.pairing
                                    radius: 999
                                    color: pairArea.containsMouse ? Theme.frameBg : Theme.tileBg
                                    border.width: 1
                                    border.color: pairArea.containsMouse ? Theme.vermDim : Theme.border
                                    height: 18 * root.s
                                    width: pairText.implicitWidth + 16 * root.s
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                    Text {
                                        id: pairText
                                        anchors.centerIn: parent
                                        text: "Pair"
                                        color: pairArea.containsMouse ? Theme.cream : Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: 9.5 * root.s
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: pairArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activateDevice(devItem.modelData)
                                    }
                                }
                            }
                        }

                        Item {
                            visible: devItem.confirming
                            width: parent.width
                            height: 30 * root.s

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: confirmBtns.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: devItem.isConnected ? "Connected" : "Paired"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 9.5 * root.s
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Row {
                                id: confirmBtns
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: primaryLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: primaryArea.containsMouse || devItem.primaryKeyFocus ? Theme.tileBg : "transparent"
                                    border.width: 1
                                    border.color: devItem.primaryKeyFocus ? Qt.alpha(Theme.vermLit, 0.85)
                                        : (primaryArea.containsMouse ? Theme.vermDim : Theme.border)

                                    Text {
                                        id: primaryLabel
                                        anchors.centerIn: parent
                                        text: devItem.isConnected ? "Disconnect" : "Connect"
                                        color: Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: primaryArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: devItem.isConnected
                                            ? root.disconnectDevice(devItem.modelData)
                                            : root.connectDevice(devItem.modelData)
                                    }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: forgetLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: forgetArea.containsMouse || devItem.forgetKeyFocus
                                        ? Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.2)
                                        : Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.12)
                                    border.width: 1
                                    border.color: devItem.forgetKeyFocus
                                        ? Qt.alpha(Theme.vermLit, 0.85)
                                        : Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.45)

                                    Text {
                                        id: forgetLabel
                                        anchors.centerIn: parent
                                        text: "Forget"
                                        color: Theme.vermLit
                                        font.family: Theme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: forgetArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.forgetDevice(devItem.modelData)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: devItem.failed
                            text: "Pairing failed"
                            color: Theme.vermLit
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            leftPadding: 42 * root.s
                        }
                    }
                }
            }
        }

        Rectangle {
            id: devScrollTrack
            visible: listFrame.scrollable
            z: 10
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 3 * root.s
            anchors.bottomMargin: 3 * root.s
            width: Math.max(3, 4 * root.s)
            radius: width / 2
            color: Theme.frameBg
            opacity: root.discovering ? 1 : 0.82

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: Math.max(18 * root.s, parent.height * Math.min(1, devFlick.height / Math.max(1, devFlick.contentHeight)))
                y: (parent.height - height) * (devFlick.contentY / Math.max(1, devFlick.contentHeight - devFlick.height))
                radius: width / 2
                color: root.discovering ? Theme.vermLit : Theme.dim
                opacity: root.discovering ? 0.95 : 0.78
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: root.s
            flick: devFlick
        }
    }
}
