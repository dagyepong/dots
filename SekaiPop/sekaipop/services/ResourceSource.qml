import Quickshell
import Quickshell.Io
import QtQuick

// The system side of the resource indicator (with MediaSource.qml,
// TraySource.qml, NotificationSource.qml, QuickSource.qml — one of the
// files that talk to the system). Polls /proc directly, so nothing
// extra needs to be installed for this one.
//
//   cpuPercent   0-100, from the delta between two /proc/stat reads
//                (a single read can't tell you usage, only totals since
//                boot — you need two samples and the difference)
//   memPercent   0-100, MemTotal vs MemAvailable from /proc/meminfo
//                (MemAvailable, not MemFree — MemFree alone counts disk
//                cache as "used", which reads as near-100% on a system
//                that's actually fine)
//   memUsedLabel / memTotalLabel   e.g. "6.1", "16.0" (GB, one decimal)
//
// Every Bar.qml instantiates its own copy (like MediaSource) — reading
// two small files every couple of seconds is cheap enough that a
// second monitor's bar doing it too isn't worth sharing state over.
Scope {
    id: root

    property real cpuPercent: 0
    property real memPercent: 0
    property string memUsedLabel: "--"
    property string memTotalLabel: "--"

    property var previousCpuStats: null

    // False stops the 5 s read of /proc (Bar.qml turns it off while the CPU & RAM
    // module is not on this bar and its popup is closed). Starting it again reads
    // at once; the CPU figure is a difference, so it is re-primed and is right
    // from the second read on, the same as right after the shell starts.
    property bool wanted: true
    onWantedChanged: if (!wanted) previousCpuStats = null

    function gbLabel(kb) {
        return (kb / (1024 * 1024)).toFixed(1)
    }

    FileView { id: meminfo; path: "/proc/meminfo" }
    FileView { id: stat; path: "/proc/stat" }

    Timer {
        interval: 5000
        running: root.wanted
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload()
            stat.reload()

            const mem = meminfo.text()
            const total = Number(mem.match(/MemTotal:\s*(\d+)/)?.[1] ?? 0)
            const avail = Number(mem.match(/MemAvailable:\s*(\d+)/)?.[1] ?? 0)
            if (total > 0) {
                root.memPercent = Math.round(100 * (total - avail) / total)
                root.memUsedLabel = root.gbLabel(total - avail)
                root.memTotalLabel = root.gbLabel(total)
            }

            const cpuLine = stat.text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const fields = cpuLine.slice(1).map(Number)
                const totalTicks = fields.reduce((a, b) => a + b, 0)
                const idleTicks = fields[3]
                if (root.previousCpuStats) {
                    const totalDiff = totalTicks - root.previousCpuStats.total
                    const idleDiff = idleTicks - root.previousCpuStats.idle
                    if (totalDiff > 0)
                        root.cpuPercent = Math.round(100 * (1 - idleDiff / totalDiff))
                }
                root.previousCpuStats = { total: totalTicks, idle: idleTicks }
            }
        }
    }
}
