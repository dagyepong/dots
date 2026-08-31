import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

Scope {
    id: rootScope

    property string osdIcon: "🔊"
    property string osdTitle: "Volume"
    property int osdPercent: 50
    property bool osdVisible: false

    Timer {
        id: osdHideTimer
        interval: 1800
        repeat: false
        onTriggered: rootScope.osdVisible = false
    }

    function triggerOsd(icon, title, value) {
        rootScope.osdIcon = icon;
        rootScope.osdTitle = title;
        rootScope.osdPercent = Math.min(100, Math.max(0, value));
        rootScope.osdVisible = true;
        osdHideTimer.restart();
    }

    Process {
        id: volPoller
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pamixer --get-volume"]
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed.startsWith("Volume:")) {
                    let isMuted = trimmed.includes("[MUTED]");
                    let val = parseFloat(trimmed.split(" ")[1]) || 0;
                    let pct = Math.round(val * 100);
                    let icon = isMuted ? "🔇" : (pct === 0 ? "🔈" : (pct > 50 ? "🔊" : "🔉"));
                    rootScope.triggerOsd(icon, isMuted ? "Muted" : "Volume", pct);
                } else {
                    let pct = parseInt(trimmed) || 0;
                    rootScope.triggerOsd("🔊", "Volume", pct);
                }
            }
        }
    }

    Process {
        id: volEventSubscriber
        command: ["bash", "-c", "pactl subscribe 2>/dev/null | grep --line-buffered \"change\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink")) {
                    volPoller.running = true;
                }
            }
        }
    }

    Process {
        id: brightnessProc
        command: ["bash", "-c", "brightnessctl --machine-readable 2>/dev/null || brightnessctl g"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(",");
                if (parts.length >= 4) {
                    let current = parseInt(parts[2]) || 0;
                    let max = parseInt(parts[3]) || 1;
                    let pct = Math.round((current / max) * 100);
                    rootScope.triggerOsd("☀️", "Brightness", pct);
                }
            }
        }
    }

    Process {
        id: brightnessEventSubscriber
        command: ["bash", "-c", "brightnessctl --monitor 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: data => { brightnessProc.running = true; }
        }
    }

    Process {
        id: kbdBrightnessProc
        command: ["bash", "-c", "brightnessctl --device='*::kbd_backlight' --machine-readable 2>/dev/null || brightnessctl -d '*::kbd_backlight' g"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(",");
                if (parts.length >= 4) {
                    let current = parseInt(parts[2]) || 0;
                    let max = parseInt(parts[3]) || 1;
                    let pct = Math.round((current / max) * 100);
                    rootScope.triggerOsd("⌨️", "Kbd Backlight", pct);
                } else {
                    let val = parseInt(data.trim()) || 0;
                    rootScope.triggerOsd("⌨️", "Kbd Backlight", val);
                }
            }
        }
    }

    Process {
        id: kbdBrightnessEventSubscriber
        command: ["bash", "-c", "brightnessctl --device='*::kbd_backlight' --monitor 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: data => { kbdBrightnessProc.running = true; }
        }
    }

    PanelWindow {
        id: root

        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true }
        margins { top: 0 }

        implicitHeight: mainPill.implicitHeight
        implicitWidth: mainPill.implicitWidth
        color: "transparent"

        Process { id: execProc }

        function runCmd(cmdStr) {
            execProc.command = ["bash", "-c", cmdStr]
            execProc.running = true
        }

        function launchAppLauncher() {
            runCmd("niri msg action spawn -- fuzzel || niri msg action spawn -- rofi -show drun || niri msg action spawn -- app-launcher")
        }

        function openWifiPicker() {
            runCmd("niri msg action spawn -- foot -e nmtui || niri msg action spawn -- nm-connection-editor")
        }

        function openBtPicker() {
            runCmd("niri msg action spawn -- blueman-manager || niri msg action spawn -- foot -e bluetoothctl")
        }

        property bool expanded: false
        property string timeStr: "00:00"
        property string dateStr: "Sun, Jan 01"
        property string dynamicAccent: "#3B82F6"

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                let d = new Date();
                root.timeStr = d.toLocaleTimeString(Qt.locale(), "hh:mm ap");
                root.dateStr = d.toLocaleDateString(Qt.locale(), "ddd, MMM dd");
            }
        }

        property bool wifiEnabled: false
        property string wifiSsid: "Disconnected"
        property bool btPowered: false

        Process {
            id: wifiInfoProc
            command: ["bash", "-c", "if [ \"$(cat /sys/class/net/w*/operstate 2>/dev/null | head -n1)\" = \"up\" ]; then nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | cut -d':' -f2 || echo 'Connected'; else echo 'OFF'; fi"]
            stdout: SplitParser {
                onRead: data => {
                    let trimmed = data.trim();
                    if (trimmed === "OFF" || trimmed === "" || trimmed === "Disconnected") {
                        root.wifiSsid = "Disconnected";
                        root.wifiEnabled = false;
                    } else {
                        root.wifiSsid = trimmed;
                        root.wifiEnabled = true;
                    }
                }
            }
        }

        Process {
            id: btStatusProc
            command: ["bash", "-c", "rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: no'"]
            onExited: (code) => { root.btPowered = (code === 0); }
        }

        property var niriWorkspaces: []
        property int activeWorkspaceId: 1

        function updateNiriWorkspaces() {
            niriWsFetchProc.running = true;
        }

        Process {
            id: niriWsFetchProc
            command: ["bash", "-c", "niri msg --json workspaces 2>/dev/null"]
            stdout: SplitParser {
                onRead: data => {
                    try {
                        let parsed = JSON.parse(data);
                        let list = [];
                        for (let i = 0; i < parsed.length; i++) {
                            let ws = parsed[i];
                            list.push({ id: ws.id, idx: ws.idx, name: ws.name || ws.idx.toString(), is_active: ws.is_active, is_focused: ws.is_focused });
                            if (ws.is_active) root.activeWorkspaceId = ws.id;
                        }
                        root.niriWorkspaces = list;
                    } catch(e) {}
                }
            }
        }

        Process {
            id: niriEventStreamProc
            command: ["bash", "-c", "niri msg --json event-stream 2>/dev/null"]
            running: true
            stdout: SplitParser {
                onRead: data => {
                    if (data.includes("WorkspaceActivated") || data.includes("WorkspacesChanged")) {
                        root.updateNiriWorkspaces();
                    }
                }
            }
        }

        property var cavaSpectrumValues: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

        Process {
            id: cavaStreamProc
            command: ["bash", "-c", "cava -p ~/.config/cava/config_quickshell 2>/dev/null"]
            running: root.hasMedia && root.isPlaying
            stdout: SplitParser {
                onRead: data => {
                    let rawValues = data.trim().split(";");
                    let bars = [];
                    for (let i = 0; i < 16; i++) {
                        let val = parseInt(rawValues[i]) || 0;
                        bars.push(Math.min(1.0, Math.max(0.0, val / 255.0)));
                    }
                    root.cavaSpectrumValues = bars;
                }
            }
        }

        property string trackTitle: "No Track Active"
        property string trackArtist: "Playerctl Idle"
        property string albumArtUrl: ""
        property bool isPlaying: false
        property bool hasMedia: false
        property real trackProgress: 0.0
        property int currentPositionSec: 0
        property int totalLengthSec: 0
        property string currentTimeStr: "0:00"
        property string totalTimeStr: "0:00"

        function formatTime(sec) {
            let m = Math.floor(sec / 60);
            let s = sec % 60;
            return m + ":" + (s < 10 ? "0" : "") + s;
        }

        function updateProgressVisuals() {
            root.trackProgress = root.totalLengthSec > 0 ? Math.min(1.0, root.currentPositionSec / root.totalLengthSec) : 0.0;
            root.currentTimeStr = root.formatTime(root.currentPositionSec);
            root.totalTimeStr = root.formatTime(root.totalLengthSec);
        }

        Timer {
            id: positionTicker
            interval: 1000
            running: root.hasMedia && root.isPlaying
            repeat: true
            onTriggered: {
                if (root.currentPositionSec < root.totalLengthSec) {
                    root.currentPositionSec += 1;
                    root.updateProgressVisuals();
                }
            }
        }

        Process {
            id: mprisFollowProc
            command: ["bash", "-c", "playerctl metadata --follow --format '{{status}};;;{{title}};;;{{artist}};;;{{mpris:artUrl}};;;{{position}};;;{{mpris:length}}' 2>/dev/null"]
            running: true
            stdout: SplitParser {
                onRead: data => {
                    let parts = data.trim().split(";;;");
                    if (parts.length >= 2 && parts[1].trim() !== "") {
                        root.hasMedia = true;
                        root.isPlaying = (parts[0] === "Playing");
                        root.trackTitle = parts[1];
                        root.trackArtist = (parts.length >= 3 && parts[2]) ? parts[2] : "Unknown Artist";
                        let newArt = (parts.length >= 4 && parts[3]) ? parts[3] : "";
                        if (newArt !== root.albumArtUrl) {
                            root.albumArtUrl = newArt;
                            if (newArt.startsWith("file://")) {
                                colorExtractProc.command = ["bash", "-c", "python3 -c \"from PIL import Image; img = Image.open('" + newArt.replace("file://", "") + "').resize((1,1)); print('#%02x%02x%02x' % img.getpixel((0,0))) 2>/dev/null\" || echo '#3B82F6'"];
                                colorExtractProc.running = true;
                            }
                        }
                        if (parts.length >= 6 && parts[5]) {
                            root.currentPositionSec = Math.floor((parseInt(parts[4]) || 0) / 1000000);
                            root.totalLengthSec = Math.floor((parseInt(parts[5]) || 1) / 1000000);
                            root.updateProgressVisuals();
                        }
                    } else {
                        root.hasMedia = false;
                        root.isPlaying = false;
                        root.trackTitle = "No Track Playing";
                        root.trackArtist = "Playerctl";
                        root.currentPositionSec = 0;
                        root.totalLengthSec = 0;
                        root.updateProgressVisuals();
                    }
                }
            }
        }

        Process {
            id: colorExtractProc
            stdout: SplitParser {
                onRead: data => {
                    let col = data.trim();
                    if (col.startsWith("#") && col.length === 7) {
                        root.dynamicAccent = col;
                    }
                }
            }
        }

        property int timerHours: 0
        property int timerMinutes: 25
        property int timerSecondsLeft: 1500
        property bool timerRunning: false

        Timer {
            id: mainPomodoroTimer
            interval: 1000
            running: root.timerRunning
            repeat: true
            onTriggered: {
                if (root.timerSecondsLeft > 0) root.timerSecondsLeft--;
                else { root.timerRunning = false; root.runCmd("notify-send 'Timer Complete!' 'Your focus session has finished.'"); }
            }
        }

        function syncTimerFromInputs() {
            if (!root.timerRunning) root.timerSecondsLeft = (root.timerHours * 3600) + (root.timerMinutes * 60);
        }

        function formatTimerDisplay(totalSecs) {
            let h = Math.floor(totalSecs / 3600);
            let m = Math.floor((totalSecs % 3600) / 60);
            let s = totalSecs % 60;
            return h > 0 ? (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m) : (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
        }

        property int cpuUsagePct: 0
        property int ramUsagePct: 0
        property string cpuTempStr: "--°C"

        Process {
            id: sysResourcesProc
            command: ["bash", "-c", "
                CPU=$(top -bn1 | grep 'Cpu(s)' | awk '{print int(100 - $8)}');
                RAM=$(free | awk '/Mem:/{print int($3/$2 * 100)}');
                TEMP=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n1);
                if [ -n \"$TEMP\" ]; then
                    TEMP_C=$((TEMP / 1000));
                    echo \"${CPU:-0}:${RAM:-0}:${TEMP_C}°C\";
                else
                    echo \"${CPU:-0}:${RAM:-0}:N/A\";
                fi
            "]
            stdout: SplitParser {
                onRead: data => {
                    let parts = data.trim().split(":");
                    if (parts.length >= 3) {
                        root.cpuUsagePct = Math.min(100, Math.max(0, parseInt(parts[0]) || 0));
                        root.ramUsagePct = Math.min(100, Math.max(0, parseInt(parts[1]) || 0));
                        root.cpuTempStr = parts[2];
                    }
                }
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: sysResourcesProc.running = true
        }

        property int batteryPctVal: 100
        property string batteryCapacity: "100%"
        property string batteryStatus: "Discharging"

        Process {
            id: batProc
            command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo '100'"]
            stdout: SplitParser { onRead: data => { root.batteryPctVal = parseInt(data.trim()) || 100; root.batteryCapacity = root.batteryPctVal + "%"; } }
        }

        Process {
            id: batStatProc
            command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null || echo 'Discharging'"]
            stdout: SplitParser { onRead: data => root.batteryStatus = data.trim() }
        }

        Timer {
            interval: 4000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                wifiInfoProc.running = true;
                btStatusProc.running = true;
                batProc.running = true;
                batStatProc.running = true;
                root.updateNiriWorkspaces();
            }
        }

        component CavaVisualizer: RowLayout {
            spacing: 2
            Repeater {
                model: 12
                delegate: Rectangle {
                    width: 3
                    height: Math.max(2, 18 * (root.cavaSpectrumValues[index] || 0))
                    radius: 1.5
                    color: root.dynamicAccent
                    Behavior on height { NumberAnimation { duration: 40; easing.type: Easing.OutQuad } }
                }
            }
        }

        component NiriWorkspaceBar: RowLayout {
            spacing: 4
            Repeater {
                model: root.niriWorkspaces
                delegate: Rectangle {
                    required property var modelData
                    width: modelData.is_active ? 16 : 6
                    height: 5
                    radius: 2.5
                    color: modelData.is_active ? root.dynamicAccent : "#44444C"
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    MouseArea { anchors.fill: parent; onClicked: root.runCmd("niri msg action focus-workspace " + modelData.idx) }
                }
            }
        }

        component ModernBatteryIcon: RowLayout {
            spacing: 4
            Text { text: root.batteryCapacity; color: "#FFFFFF"; font.pixelSize: 10; font.bold: true }
            Item {
                width: 20; height: 10
                Rectangle {
                    anchors.fill: parent; radius: 2.5; color: "transparent"
                    border.color: root.batteryStatus === "Charging" ? "#00FF88" : (root.batteryPctVal <= 20 ? "#FF453A" : "#FFFFFF")
                    border.width: 1.2
                    Rectangle {
                        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 1.5
                        width: Math.max(2, (parent.width - 3) * (root.batteryPctVal / 100.0)); radius: 1.2; color: parent.border.color
                    }
                }
                Rectangle {
                    width: 1.5; height: 3.5; radius: 0.75
                    color: root.batteryStatus === "Charging" ? "#00FF88" : (root.batteryPctVal <= 20 ? "#FF453A" : "#FFFFFF")
                    anchors.left: parent.right; anchors.leftMargin: 1; anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        component ActivePlayerCard: ColumnLayout {
            spacing: 10
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.runCmd("foot -e cava");
                    } else {
                        root.runCmd("playerctl play-pause");
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 8; color: "#1A1A1E"; clip: true
                    Image { anchors.fill: parent; source: root.albumArtUrl; fillMode: Image.PreserveAspectCrop; visible: root.albumArtUrl !== "" }
                    Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 18; visible: root.albumArtUrl === "" }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { text: root.trackTitle; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: root.trackArtist; color: "#7D8BA1"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                CavaVisualizer {}
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: root.currentTimeStr; color: "#8E8E93"; font.pixelSize: 11 }
                Rectangle {
                    Layout.fillWidth: true; height: 4; radius: 2; color: "#333336"
                    Rectangle { height: parent.height; width: parent.width * root.trackProgress; radius: 2; color: root.dynamicAccent }
                }
                Text { text: root.totalTimeStr; color: "#8E8E93"; font.pixelSize: 11 }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 22
                Text { text: "⏮"; color: "#FFFFFF"; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: root.runCmd("playerctl previous") } }
                Text { text: root.isPlaying ? "⏸" : "▶"; color: "#FFFFFF"; font.pixelSize: 20; MouseArea { anchors.fill: parent; onClicked: root.runCmd("playerctl play-pause") } }
                Text { text: "⏭"; color: "#FFFFFF"; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: root.runCmd("playerctl next") } }
            }
        }

        Rectangle {
            id: mainPill
            property bool showStandalonePlayer: !root.expanded && root.hasMedia && root.isPlaying
            implicitHeight: root.expanded ? 700 : (showStandalonePlayer ? 110 : 30)
            implicitWidth: root.expanded ? 800 : (showStandalonePlayer ? 320 : compactContent.implicitWidth + 24)
            
            radius: root.expanded ? 24 : (showStandalonePlayer ? 18 : 15)
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.expanded ? 24 : (showStandalonePlayer ? 18 : 15)
            bottomRightRadius: root.expanded ? 24 : (showStandalonePlayer ? 18 : 15)

            color: "#000000"
            transformOrigin: Item.Top

            transform: Scale {
                id: dropletScale
                yScale: 1.0
                xScale: 1.0
                origin.x: mainPill.width / 2
                origin.y: 0
            }

            Behavior on implicitWidth {
                SpringAnimation {
                    spring: 4.2
                    damping: 0.30
                    epsilon: 0.1
                }
            }
            Behavior on implicitHeight {
                SpringAnimation {
                    spring: 4.8
                    damping: 0.22
                    epsilon: 0.1
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }

            Item {
                anchors.fill: parent; anchors.margins: 12; visible: mainPill.showStandalonePlayer
                ActivePlayerCard { anchors.fill: parent }
            }

            RowLayout {
                id: compactContent
                anchors.centerIn: parent; height: 30; spacing: 8
                visible: !root.expanded && !mainPill.showStandalonePlayer

                Rectangle {
                    width: 18; height: 18; radius: 9; color: "#1E1E24"
                    Text { anchors.centerIn: parent; text: "🔍"; font.pixelSize: 9 }
                    MouseArea { anchors.fill: parent; onClicked: root.launchAppLauncher() }
                }

                NiriWorkspaceBar {}

                Rectangle { width: 1; height: 10; color: "#FFFFFF"; opacity: 0.15 }

                Text {
                    text: root.timeStr
                    color: "#FFFFFF"
                    font.pixelSize: 10
                    font.bold: true
                }

                Rectangle { width: 1; height: 10; color: "#FFFFFF"; opacity: 0.15 }

                RowLayout {
                    spacing: 3
                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            width: 14; height: 14
                            required property var modelData
                            Image { anchors.centerIn: parent; width: 12; height: 12; source: modelData.icon || ""; fillMode: Image.PreserveAspectFit; smooth: true }
                        }
                    }
                }

                Rectangle { width: 1; height: 10; color: "#FFFFFF"; opacity: 0.15 }
                ModernBatteryIcon {}
            }

            ColumnLayout {
                id: expandedContent
                anchors.fill: parent; anchors.margins: 18; spacing: 14
                visible: root.expanded
                opacity: root.expanded ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    Layout.fillWidth: true
                    RowLayout {
                        spacing: 8
                        Text { text: root.timeStr; color: "#FFFFFF"; font.pixelSize: 20; font.bold: true }
                        Text { text: root.dateStr; color: "#888888"; font.pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    NiriWorkspaceBar {}
                    Item { Layout.fillWidth: true }
                    ModernBatteryIcon {}
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Rectangle {
                        Layout.fillWidth: true; height: 54; radius: 14
                        color: root.wifiEnabled ? "#1E293B" : "#141418"
                        border.color: root.wifiEnabled ? root.dynamicAccent : "transparent"; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Text { text: "📶"; font.pixelSize: 14; MouseArea { anchors.fill: parent; onClicked: { root.runCmd(root.wifiEnabled ? "rfkill block wlan || nmcli radio wifi off" : "rfkill unblock wlan || nmcli radio wifi on"); root.wifiEnabled = !root.wifiEnabled; } } }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: "Wi-Fi"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 12 }
                                Text { text: root.wifiSsid; color: root.wifiEnabled ? "#60A5FA" : "#888888"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                                MouseArea { anchors.fill: parent; onClicked: root.openWifiPicker() }
                            }
                            Text { text: "⚙"; color: "#888888"; font.pixelSize: 12; MouseArea { anchors.fill: parent; onClicked: root.openWifiPicker() } }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 54; radius: 14
                        color: root.btPowered ? "#2E1065" : "#141418"
                        border.color: root.btPowered ? root.dynamicAccent : "transparent"; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Text { text: "ᛡ"; color: root.btPowered ? root.dynamicAccent : "#FFFFFF"; font.pixelSize: 14; MouseArea { anchors.fill: parent; onClicked: { root.runCmd(root.btPowered ? "rfkill block bluetooth || bluetoothctl power off" : "rfkill unblock bluetooth || bluetoothctl power on"); root.btPowered = !root.btPowered; } } }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: "Bluetooth"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 12 }
                                Text { text: root.btPowered ? "Active" : "Off"; color: root.btPowered ? root.dynamicAccent : "#888888"; font.pixelSize: 10 }
                                MouseArea { anchors.fill: parent; onClicked: root.openBtPicker() }
                            }
                            Text { text: "⚙"; color: "#888888"; font.pixelSize: 12; MouseArea { anchors.fill: parent; onClicked: root.openBtPicker() } }
                        }
                    }
                }

                TailscaleCard { Layout.fillWidth: true }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 120; radius: 16; color: "#0F0F12"; clip: true
                    Item { anchors.fill: parent; anchors.margins: 12; ActivePlayerCard { anchors.fill: parent } }
                }

                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 16; color: "#141418"
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text { text: "System Monitor"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 11 }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "CPU"; color: "#AAAAAA"; font.pixelSize: 10; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Text { text: root.cpuUsagePct + "%"; color: "#FFFFFF"; font.pixelSize: 10 }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 5; radius: 2.5; color: "#222228"
                                        Rectangle {
                                            height: parent.height; width: parent.width * (root.cpuUsagePct / 100.0); radius: 2.5
                                            color: root.cpuUsagePct > 85 ? "#FF453A" : root.dynamicAccent
                                        }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "RAM"; color: "#AAAAAA"; font.pixelSize: 10; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Text { text: root.ramUsagePct + "%"; color: "#FFFFFF"; font.pixelSize: 10 }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 5; radius: 2.5; color: "#222228"
                                        Rectangle {
                                            height: parent.height; width: parent.width * (root.ramUsagePct / 100.0); radius: 2.5
                                            color: root.ramUsagePct > 85 ? "#FF9500" : root.dynamicAccent
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Temperature"; color: "#AAAAAA"; font.pixelSize: 10 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: root.cpuTempStr; color: "#00FF88"; font.pixelSize: 10; font.bold: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
