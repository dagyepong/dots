import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: osdRoot

    // OSD State Variables
    property string activeIcon: "🔊"
    property string activeTitle: "Volume"
    property int activePercent: 50
    property bool osdVisible: false

    // Auto-hide Timer (hides HUD 1.8s after key release)
    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: osdRoot.osdVisible = false
    }

    function triggerOsd(icon, title, value) {
        osdRoot.activeIcon = icon;
        osdRoot.activeTitle = title;
        osdRoot.activePercent = Math.min(100, Math.max(0, value));
        osdRoot.osdVisible = true;
        hideTimer.restart();
    }

    // -------------------------------------------------------------------------
    // 1. VOLUME MONITOR PROCESS
    // -------------------------------------------------------------------------
    Process {
        id: volPoller
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pamixer --get-volume"]
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                // wpctl output format: "Volume: 0.45 [MUTED]" or "Volume: 0.65"
                if (trimmed.startsWith("Volume:")) {
                    let isMuted = trimmed.includes("[MUTED]");
                    let val = parseFloat(trimmed.split(" ")[1]) || 0;
                    let pct = Math.round(val * 100);
                    let icon = isMuted ? "🔇" : (pct === 0 ? "🔈" : (pct > 50 ? "🔊" : "🔉"));
                    osdRoot.triggerOsd(icon, isMuted ? "Muted" : "Volume", pct);
                } else {
                    // pamixer numeric output fallback
                    let pct = parseInt(trimmed) || 0;
                    osdRoot.triggerOsd("🔊", "Volume", pct);
                }
            }
        }
    }

    Process {
        id: volEventSubscriber
        // Listens to WirePlumber/PipeWire audio events continuously
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

    // -------------------------------------------------------------------------
    // 2. BRIGHTNESS MONITOR PROCESS (brightnessctl)
    // -------------------------------------------------------------------------
    Process {
        id: brightnessProc
        command: ["bash", "-c", "brightnessctl --machine-readable 2>/dev/null || brightnessctl g"]
        stdout: SplitParser {
            onRead: data => {
                // Machine-readable output format: device,class,current,max,percent
                let parts = data.trim().split(",");
                if (parts.length >= 4) {
                    let current = parseInt(parts[2]) || 0;
                    let max = parseInt(parts[3]) || 1;
                    let pct = Math.round((current / max) * 100);
                    osdRoot.triggerOsd("☀️", "Brightness", pct);
                }
            }
        }
    }

    Process {
        id: brightnessEventSubscriber
        // Listens to sysfs backlight updates from brightnessctl
        command: ["bash", "-c", "brightnessctl --monitor 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                brightnessProc.running = true;
            }
        }
    }

    // -------------------------------------------------------------------------
    // 3. OVERLAY WAYLAND PANEL WINDOW
    // -------------------------------------------------------------------------
    PanelWindow {
        id: osdWindow
        
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        anchors {
            bottom: true
        }
        margins {
            bottom: 70
        }

        implicitWidth: 240
        implicitHeight: 64
        color: "transparent"
        visible: osdRoot.osdVisible

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#121216"
            border.color: "#2A2A32"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    text: osdRoot.activeIcon
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: osdRoot.activeTitle
                            color: "#8E8E93"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: osdRoot.activePercent + "%"
                            color: "#FFFFFF"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    // Dynamic Slider Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: "#22222A"

                        Rectangle {
                            height: parent.height
                            width: parent.width * (osdRoot.activePercent / 100.0)
                            radius: 3
                            color: osdRoot.activeTitle === "Brightness" ? "#F59E0B" : "#3B82F6"

                            Behavior on width {
                                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }
        }
    }
}
