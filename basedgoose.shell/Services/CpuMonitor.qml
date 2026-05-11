import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons" as Commons

Item {
    id: cpuMonitor
    
    property int cpuUsage: 0
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0
    
    Process {
        id: cpuProc
        running: false
        command: ["sh", "-c", "cat /proc/stat | grep '^cpu '"]
        
        stdout: StdioCollector {
            id: cpuCollector
            onStreamFinished: {
                var output = text.trim();
                var line = output.split(/\s+/);
                var idle = parseInt(line[4]);
                var total = 0;
                for (var i = 1; i < line.length; i++) {
                    total += parseInt(line[i]);
                }
                
                if (cpuMonitor.lastCpuTotal > 0) {
                    var idleDiff = idle - cpuMonitor.lastCpuIdle;
                    var totalDiff = total - cpuMonitor.lastCpuTotal;
                    cpuMonitor.cpuUsage = Math.round(100 * (1 - idleDiff / totalDiff));
                }
                
                cpuMonitor.lastCpuIdle = idle;
                cpuMonitor.lastCpuTotal = total;
                cpuTimer.start();
            }
        }
    }
    
    Timer {
        id: cpuTimer
        interval: Commons.Config.cpuUpdateInterval
        running: true
        onTriggered: cpuProc.running = true
    }
    
    Component.onCompleted: {
        cpuProc.running = true;
    }
}
