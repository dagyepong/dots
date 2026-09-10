pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpuUsage: 0
    property real memUsage: 0
    readonly property bool isUnderLoad: cpuUsage > 0.7 || memUsage > 0.85

    property real _lastCpuTotal: 0
    property real _lastCpuIdle: 0

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { cpuFile.reload(); memFile.reload(); }
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        onLoaded: {
            const m = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (!m) return;
            const stats = []; for (var i = 1; i <= 7; i++) stats.push(parseInt(m[i], 10));
            const total = stats.reduce(function(a, b) { return a + b; }, 0);
            const idle = stats[3] + (stats[4] || 0);
            const dt = total - root._lastCpuTotal;
            const di = idle - root._lastCpuIdle;
            if (dt > 0 && root._lastCpuTotal > 0) root.cpuUsage = 1 - di / dt;
            root._lastCpuTotal = total;
            root._lastCpuIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const txt = text();
            const total = parseInt((txt.match(/MemTotal:\s*(\d+)/) || [])[1] || "1", 10);
            const avail = parseInt((txt.match(/MemAvailable:\s*(\d+)/) || [])[1] || "0", 10);
            if (total > 0) root.memUsage = (total - avail) / total;
        }
    }
}
