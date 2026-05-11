import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons" as Commons

Item {
    id: memoryMonitor
    
    property int memUsage: 0
    property real memTotal: 0.0
    property real memUsed: 0.0
    
    Process {
        id: memProc
        running: false
        command: ["sh", "-c", "free -m | grep Mem"]
        
        stdout: StdioCollector {
            id: memCollector
            onStreamFinished: {
                var output = text.trim();
                var line = output.split(/\s+/);
                memoryMonitor.memTotal = parseFloat(line[1]) / 1024;
                memoryMonitor.memUsed = parseFloat(line[2]) / 1024;
                memoryMonitor.memUsage = Math.round(100 * memoryMonitor.memUsed / memoryMonitor.memTotal);
                memTimer.start();
            }
        }
    }
    
    Timer {
        id: memTimer
        interval: Commons.Config.memoryUpdateInterval
        running: true
        onTriggered: memProc.running = true
    }
    
    Component.onCompleted: {
        memProc.running = true;
    }
}
