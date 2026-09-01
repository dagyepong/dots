pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * SYSTEM surface: live machine vitals fed by the Sysmon singleton. GPU dials are
 * generated from Sysmon.gpus, so mixed Intel/NVIDIA systems can show each card
 * separately while still degrading cleanly when a telemetry backend is missing.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 16

    implicitHeight: content.implicitHeight

    readonly property var blankGpu: ({
        "shortLabel": "GPU",
        "load": -1,
        "temp": -1,
        "vramTemp": -1,
        "hasVram": false,
        "vramUsedGb": 0,
        "vramTotalGb": 0,
        "status": ""
    })

    readonly property var dialItems: {
        var items = [{ "kind": "cpu" }];
        for (var i = 0; i < Sysmon.gpus.length; i++)
            items.push({ "kind": "gpu", "index": i });
        items.push({ "kind": "mem" });
        return items;
    }

    readonly property var cellItems: {
        return [{ "kind": "net" }, { "kind": "disk" }, { "kind": "swap" }];
    }

    onActiveChanged: Sysmon.open = active

    readonly property point soulPoint: {
        void root.width;
        void root.height;
        if (Flags.showGlyphs)
            return kanji.mapToItem(root, kanji.width / 2, -3 * root.s);
        return sysLabel.mapToItem(root, -8 * root.s, sysLabel.height / 2);
    }

    ameForm: open ? "soul" : "off"
    amePoint: soulPoint

    function gpuTemp(g) {
        if (!g)
            return "";
        if (g.temp >= 0 && g.vramTemp >= 0 && g.vramTemp !== g.temp)
            return g.temp + "°/" + g.vramTemp + "°";
        if (g.temp >= 0)
            return g.temp + "°";
        if (g.status === "offline")
            return "n/a";
        return "";
    }

    function gpuVram(g) {
        if (g && g.hasVram && g.vramTotalGb > 0)
            return g.vramUsedGb.toFixed(1) + "/" + g.vramTotalGb.toFixed(0) + "G";
        return "";
    }

    component Dial: Item {
        id: dial

        property real arc: 0
        property string big: ""
        property string unit: ""
        property string sub: ""
        property string sub2: ""
        property string label: ""
        property bool shrink: false

        property real display: 0
        onArcChanged: display = arc
        Component.onCompleted: display = arc
        onDisplayChanged: face.requestPaint()
        Behavior on display { NumberAnimation { duration: Math.round(700 * Motion.mult); easing.type: Easing.OutCubic } }

        width: 110 * root.s
        height: 110 * root.s

        Canvas {
            id: face
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var lw = 8 * root.s;
                var r = Math.min(width, height) / 2 - lw / 2 - root.s;
                var start = 135 * Math.PI / 180;
                var full = 270 * Math.PI / 180;
                ctx.lineCap = "round";
                ctx.lineWidth = lw;
                ctx.strokeStyle = Theme.hair;
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, start + full, false);
                ctx.stroke();
                var v = Math.max(0, Math.min(100, dial.display));
                if (v > 0.5) {
                    var diag = r * 0.7071;
                    var grad = ctx.createLinearGradient(cx - diag, cy + diag, cx + diag, cy - diag);
                    grad.addColorStop(0, Theme.vermBurn);
                    grad.addColorStop(0.35, Theme.vermBurn);
                    grad.addColorStop(1, Theme.vermLit);
                    ctx.strokeStyle = grad;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, start + full * v / 100, false);
                    ctx.stroke();
                }
            }
        }

        Row {
            id: bigRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -12 * root.s
            spacing: 1 * root.s

            Text {
                id: bigText
                text: dial.big
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: (dial.shrink ? 16 : 20) * root.s
                font.weight: Font.ExtraBold
                font.letterSpacing: -0.5 * root.s
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.baseline: bigText.baseline
                visible: dial.unit.length > 0
                text: dial.unit
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Bold
            }
        }

        Column {
            anchors.top: bigRow.bottom
            anchors.topMargin: 3 * root.s
            anchors.horizontalCenter: bigRow.horizontalCenter
            spacing: 2 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.label
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1 * root.s
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.sub
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: dial.sub2.length > 0
                text: dial.sub2
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Text {
                    id: kanji
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "系"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    id: sysLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SYSTEM"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.8 * root.s
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Sysmon.uptime
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
                font.features: { "tnum": 1 }
            }
        }

        Item { width: 1; height: 16 * root.s }

        Item {
            width: parent.width
            height: 110 * root.s

            Repeater {
                model: root.dialItems

                Dial {
                    required property int index
                    required property var modelData
                    readonly property string kind: modelData.kind
                    readonly property int gpuIndex: modelData.index === undefined ? -1 : modelData.index
                    readonly property var gpuInfo: kind === "gpu" && gpuIndex >= 0 && Sysmon.gpus.length > gpuIndex ? Sysmon.gpus[gpuIndex] : root.blankGpu
                    readonly property int val: kind === "cpu" ? Sysmon.cpu : kind === "gpu" ? gpuInfo.load : Sysmon.memPct

                    x: root.dialItems.length > 1
                        ? index * (parent.width - width) / (root.dialItems.length - 1)
                        : (parent.width - width) / 2

                    arc: kind === "gpu" && val < 0 ? 0 : val
                    big: kind === "mem" ? Sysmon.memUsedGb.toFixed(1)
                        : kind === "gpu" && val < 0 ? "--"
                        : "" + val
                    unit: kind === "mem" || (kind === "gpu" && val < 0) ? "" : "%"
                    shrink: kind !== "mem" && val >= 100
                    label: kind === "gpu" ? gpuInfo.shortLabel : kind
                    sub: kind === "cpu" ? (Sysmon.cpuTemp >= 0 ? Sysmon.cpuTemp + "°" : "")
                        : kind === "gpu" ? root.gpuTemp(gpuInfo)
                        : "/ " + Sysmon.memTotalGb.toFixed(0) + " GB"
                    sub2: kind === "gpu" ? root.gpuVram(gpuInfo) : ""
                }
            }
        }

        Item { width: 1; height: 18 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 13 * root.s }

        Item {
            width: parent.width
            height: 30 * root.s

            Repeater {
                model: root.cellItems

                Item {
                    id: cell
                    required property int index
                    required property var modelData
                    readonly property string kind: modelData.kind

                    width: parent.width / root.cellItems.length
                    height: parent.height
                    x: index * width

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 2 * root.s
                        anchors.bottomMargin: 2 * root.s
                        height: parent.height - 4 * root.s
                        width: 1
                        visible: cell.index > 0
                        color: Theme.hairSoft
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6 * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.kind === "net" ? "Net · MB/s"
                                : cell.kind === "disk" ? "Disk · %"
                                : "Swap · GB"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.9 * root.s
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8 * root.s
                            visible: cell.kind === "net"

                            Text {
                                text: "↓" + Sysmon.netDown.toFixed(1)
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 13 * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                text: "↑" + Sysmon.netUp.toFixed(1)
                                color: Theme.vermLit
                                font.family: Theme.font
                                font.pixelSize: 13 * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: cell.kind !== "net"
                            text: cell.kind === "disk" ? "" + Sysmon.diskPct
                                : Sysmon.swapUsedGb.toFixed(1)
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 13 * root.s
                            font.weight: Font.ExtraBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
