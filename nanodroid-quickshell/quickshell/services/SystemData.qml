pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Service providing system performance metrics using 'dgop'.
 * Highly accurate CPU, RAM, Swap, and Temperature tracking.
 * Supports multiple disk monitoring via Config settings.
 */
Singleton {
    id: root

    property real cpuUsage: 0
    property real cpuTemperature: 0
    property string cpuModel: ""
    property int cpuThreads: 1
    property int physicalCores: 1
    
    Process {
        id: coreDetectProc
        command: ["bash", "-c", "grep '^cpu cores' /proc/cpuinfo | head -n1 | awk '{print $4}' || echo 1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(this.text.trim());
                if (!isNaN(val)) root.physicalCores = val;
            }
        }
    }
    
    property real memUsage: 0
    property real swapUsage: 0
    property real totalMemoryMB: 0
    property real usedMemoryMB: 0
    
    property real networkRxRate: 0
    property real networkTxRate: 0
    readonly property real networkTotalRate: networkRxRate + networkTxRate
    
    property real diskReadRate: 0
    property real diskWriteRate: 0
    readonly property real diskTotalRate: diskReadRate + diskWriteRate
    
    // System stats
    property string loadAverage: ""
    property int processCount: 0
    property int threadCount: 0
    property string uptime: ""
    
    // List of objects: { mount: string, usage: real, total: real, used: real }
    property var diskStats: []
    
    // Processes (Disabled for now to fix SIGSEGV)
    property var allProcesses: []
    
    // GPUs
    property var availableGpus: []
    readonly property bool hasValidGpuData: availableGpus.length > 0
    readonly property real primaryGpuTemperature: {
        const list = root.availableGpus || [];
        for (let i = 0; i < list.length; i++) {
            if ((list[i].temp || 0) > 0) return list[i].temp;
        }
        return 0;
    }
    readonly property string primaryGpuStatus: {
        const list = root.availableGpus || [];
        if (list.length === 0) return "No GPU";
        for (let i = 0; i < list.length; i++) {
            const text = root.gpuTemperatureText(list[i]);
            if (text !== "--" && text !== "Asleep" && text !== "No sensor") return text;
        }
        return root.gpuTemperatureText(list[0]);
    }

    // History tracking
    readonly property int historySize: 60
    property var cpuHistory: []
    property var memHistory: []
    property var networkRxHistory: []
    property var networkTxHistory: []
    property var diskReadHistory: []
    property var diskWriteHistory: []

    function addToHistory(array, value) {
        let newArray = (array || []).slice();
        newArray.push(value);
        if (newArray.length > historySize) {
            newArray.shift();
        }
        return newArray;
    }

    // State for adaptive polling
    property int cycleCount: 0
    readonly property bool isMonitorActive: GlobalStates.systemMonitorOpen
    readonly property bool isProcessPageActive: isMonitorActive && GlobalStates.systemMonitorIndex === 2
    readonly property bool isQuickSettingsOpen: GlobalStates.quickSettingsOpen
    readonly property bool isOverviewOpen: GlobalStates.overviewOpen
    readonly property bool isFullscreen: HyprlandData.fullscreenActive
    
    // showSpeed determines if the status bar needs network stats
    readonly property bool showSpeed: Config.options.bar ? Config.options.bar.show_network_speed : false
    
    // We pause polling when no panel consuming the metrics is open
    readonly property bool isAnyPanelOpen: isMonitorActive || isQuickSettingsOpen || isOverviewOpen || (!isFullscreen && showSpeed)
    readonly property bool shouldPause: !isAnyPanelOpen
    
    // Command and interval selection
    readonly property string activeModules: {
        if (shouldPause) return "";
        // Process enumeration is the expensive part of dgop, so only enable it
        // while the Processes tab is visible.
        if (isProcessPageActive) return "cpu,memory,diskmounts,network,disk,system,processes,gpu";
        if (isMonitorActive || isQuickSettingsOpen) return "cpu,memory,diskmounts,network,disk,system,gpu";
        
        return "cpu,memory,diskmounts,network,disk,system";
    }

    readonly property int activeInterval: isProcessPageActive ? 3000 : (isMonitorActive ? 2000 : 3000)

    // Internal state for rate calculations
    property var lastNetworkStats: null
    property var lastDiskStats: null
    property var lastUpdateTime: 0
    property bool updatePending: false
    property int lastNvidiaPoll: 0
    property int lastGpuHwmonPoll: 0

    function update() {
        if (shouldPause) return;
        if (!dgopProcess.running && !updatePending) {
            updatePending = true;
            dgopProcess.running = true;
            cycleCount++;
        }
    }

    function gpuTemperatureText(gpu) {
        if (!gpu) return "--";
        if ((gpu.temp || 0) > 0) return `${Math.round(gpu.temp)}°C`;

        const identity = `${gpu.vendor || ""} ${gpu.name || ""}`.toLowerCase();
        if (identity.includes("nvidia") && !(gpu.driver || "").trim()) return "Driver inactive";
        if ((gpu.hwmon || "") === "unknown") return "No sensor";
        return "Asleep";
    }

    function mergeGpu(vendorHint, name, temp, usage, power, driver, hwmon) {
        let list = (root.availableGpus || []).slice();
        let index = -1;
        const normalizedVendor = (vendorHint || "").toLowerCase();
        const normalizedName = (name || "").toLowerCase();

        for (let i = 0; i < list.length; i++) {
            const vendor = (list[i].vendor || "").toLowerCase();
            const gpuName = (list[i].name || "").toLowerCase();
            if ((normalizedVendor && vendor.includes(normalizedVendor))
                    || (normalizedVendor && gpuName.includes(normalizedVendor))
                    || (normalizedName && gpuName.includes(normalizedName))
                    || (normalizedName.includes("geforce") && gpuName.includes("geforce"))
                    || (normalizedName.includes("rtx") && gpuName.includes("rtx"))) {
                index = i;
                break;
            }
        }

        const existing = index >= 0 ? list[index] : {};
        const merged = {
            name: name || existing.name || "GPU",
            vendor: vendorHint || existing.vendor || "",
            temp: Math.round(temp || existing.temp || 0),
            usage: isNaN(usage) ? (existing.usage || 0) : usage,
            power: isNaN(power) ? (existing.power || 0) : power,
            driver: driver || existing.driver || "",
            pciId: existing.pciId || "",
            hwmon: hwmon || existing.hwmon || ""
        };

        if (index >= 0) list[index] = merged;
        else list.unshift(merged);
        root.availableGpus = list;
    }

    function mergeNvidiaGpu(name, temp, usage, power, driver) {
        root.mergeGpu("NVIDIA", name, temp, usage, power, driver || "nvidia", "nvidia-smi");
    }

    function refreshNvidiaGpu() {
        if (!isMonitorActive && !isQuickSettingsOpen) return;
        const now = Date.now();
        if (nvidiaGpuProcess.running || (now - lastNvidiaPoll) < 5000) return;
        lastNvidiaPoll = now;
        nvidiaGpuProcess.running = true;
    }

    function refreshGpuHwmon() {
        if (!isMonitorActive && !isQuickSettingsOpen) return;
        const now = Date.now();
        if (gpuHwmonProcess.running || (now - lastGpuHwmonPoll) < 5000) return;
        lastGpuHwmonPoll = now;
        gpuHwmonProcess.running = true;
    }

    Timer {
        id: updateTimer
        interval: root.activeInterval
        running: !root.shouldPause
        repeat: true
        triggeredOnStart: false
        onTriggered: root.update()
    }
    
    // Trigger update immediately when monitor opens for snappier feel
    Connections {
        target: GlobalStates
        function onSystemMonitorOpenChanged() {
            if (GlobalStates.systemMonitorOpen) {
                root.update();
            }
        }
    }

    Process {
        id: dgopProcess
        command: ["/usr/bin/dgop", "meta", "--json", "--modules", root.activeModules]
        
        stdout: StdioCollector {
            onStreamFinished: {
                const results = this.text;
                root.updatePending = false; // Allow next update
                
                if (!results || results.trim() === "") return;
                
                // Offload processing to next event loop tick to avoid blocking/SIGSEGV in signal handler
                Qt.callLater(() => {
                    try {
                        let jsonText = results.trim();
                        let start = jsonText.indexOf('{');
                        let end = jsonText.lastIndexOf('}');
                        if (start === -1 || end === -1) return;
                        
                        const data = JSON.parse(jsonText.substring(start, end + 1));
                        const now = Date.now();
                        const timeDiff = root.lastUpdateTime > 0 ? Math.max(0.1, (now - root.lastUpdateTime) / 1000) : (root.activeInterval / 1000);
                        root.lastUpdateTime = now;

                        if (data.cpu) {
                            root.cpuUsage = (data.cpu.usage || 0) / 100;
                            root.cpuTemperature = data.cpu.temperature || 0;
                            root.cpuModel = data.cpu.model || "";
                            root.cpuThreads = data.cpu.count || 1;
                            root.cpuHistory = root.addToHistory(root.cpuHistory, root.cpuUsage * 100);
                        }

                        if (data.memory) {
                            root.memUsage = (data.memory.usedPercent || 0) / 100;
                            root.totalMemoryMB = Math.round((data.memory.total || 0) / 1024);
                            root.usedMemoryMB = Math.round((data.memory.used || (data.memory.total - data.memory.available) || 0) / 1024);
                            const totalSwap = data.memory.swaptotal || 0;
                            const freeSwap = data.memory.swapfree || 0;
                            root.swapUsage = totalSwap > 0 ? (totalSwap - freeSwap) / totalSwap : 0;
                            root.memHistory = root.addToHistory(root.memHistory, root.memUsage * 100);
                        }

                        if (data.network && Array.isArray(data.network)) {
                            let totalRx = 0, totalTx = 0;
                            data.network.forEach(iface => { totalRx += iface.rx || 0; totalTx += iface.tx || 0; });
                            if (root.lastNetworkStats) {
                                root.networkRxRate = Math.max(0, (totalRx - root.lastNetworkStats.rx) / timeDiff);
                                root.networkTxRate = Math.max(0, (totalTx - root.lastNetworkStats.tx) / timeDiff);
                            }
                            root.lastNetworkStats = { rx: totalRx, tx: totalTx };
                            root.networkRxHistory = root.addToHistory(root.networkRxHistory, root.networkRxRate / 1024);
                            root.networkTxHistory = root.addToHistory(root.networkTxHistory, root.networkTxRate / 1024);
                        }

                        if (data.disk && Array.isArray(data.disk)) {
                            let totalRead = 0, totalWrite = 0;
                            data.disk.forEach(disk => { totalRead += (disk.read || 0) * 512; totalWrite += (disk.write || 0) * 512; });
                            if (root.lastDiskStats) {
                                root.diskReadRate = Math.max(0, (totalRead - root.lastDiskStats.read) / timeDiff);
                                root.diskWriteRate = Math.max(0, (totalWrite - root.lastDiskStats.write) / timeDiff);
                            }
                            root.lastDiskStats = { read: totalRead, write: totalWrite };
                            root.diskReadHistory = root.addToHistory(root.diskReadHistory, root.diskReadRate / (1024 * 1024));
                            root.diskWriteHistory = root.addToHistory(root.diskWriteHistory, root.diskWriteRate / (1024 * 1024));
                        }

                        if (data.system) {
                            root.loadAverage = data.system.loadavg || "";
                            root.processCount = data.system.processes || 0;
                            root.threadCount = data.system.threads || 0;
                            if (data.system.boottime) {
                                const bootDate = new Date(data.system.boottime.replace(" ", "T"));
                                if (!isNaN(bootDate.getTime())) {
                                    const seconds = Math.floor((now - bootDate) / 1000);
                                    const days = Math.floor(seconds / (24 * 3600)), remHours = Math.floor((seconds % (24 * 3600)) / 3600), remMins = Math.floor((seconds % 3600) / 60);
                                    if (days > 0) root.uptime = `${days}d ${remHours}h ${remMins}m`;
                                    else if (remHours > 0) root.uptime = `${remHours}h ${remMins}m`;
                                    else root.uptime = `${remMins}m`;
                                }
                            }
                        }

                        if (data.diskmounts && Array.isArray(data.diskmounts)) {
                            let monitored = [{ "path": "/", "alias": "System" }];
                            if (Config.options.system && Config.options.system.monitoredDisks) {
                                monitored = Config.options.system.monitoredDisks;
                            }
                            let newStats = [];
                            monitored.forEach(diskInfo => {
                                const path = diskInfo.path || "/", alias = diskInfo.alias || "", hasAlias = alias !== "" && alias !== path, displayLabel = hasAlias ? alias : path;
                                const disk = data.diskmounts.find(m => m.mount === path || m.mountpoint === path);
                                if (disk) {
                                    let pctValue = disk.percent_used || 0;
                                    if (typeof disk.percent === 'string') pctValue = parseFloat(disk.percent.replace('%', ''));
                                    newStats.push({ path: path, label: displayLabel.toUpperCase(), hasAlias: hasAlias, usage: isNaN(pctValue) ? 0 : pctValue / 100, total: root.parseSizeToMB(disk.size || disk.total_bytes), used: root.parseSizeToMB(disk.used || disk.used_bytes) });
                                }
                            });
                            if (JSON.stringify(root.diskStats) !== JSON.stringify(newStats)) root.diskStats = newStats;
                        }

                        if (data.processes && Array.isArray(data.processes)) {
                            // Cap at top 150 by CPU to avoid inflating the ListView
                            // with hundreds of idle processes — most have cpu=0 anyway.
                            const sorted = data.processes.slice().sort((a, b) => (b.cpu || 0) - (a.cpu || 0));
                            root.allProcesses = sorted.slice(0, 150).map(proc => ({
                                pid: proc.pid || 0,
                                command: proc.command || "",
                                fullCommand: proc.fullCommand || "",
                                cpu: proc.cpu || 0,
                                memoryKB: proc.memoryKB || proc.pssKB || 0,
                                username: proc.username || ""
                            }));
                        } else if (!isProcessPageActive) {
                            root.allProcesses = []; // Clear when not monitoring to save memory
                        }

                        if (data.gpu && (data.gpu.gpus || Array.isArray(data.gpu))) {
                            const gpus = Array.isArray(data.gpu) ? data.gpu : data.gpu.gpus;
                            let needsNvidiaFallback = false;
                            let needsHwmonFallback = false;
                            root.availableGpus = gpus.map(gpu => ({
                                name: gpu.displayName || gpu.name || "GPU",
                                vendor: gpu.vendor || "",
                                temp: Math.round(gpu.temperature || 0),
                                pciId: gpu.pciId || "",
                                driver: gpu.driver || "",
                                usage: gpu.usage || 0,
                                power: gpu.power || 0,
                                hwmon: gpu.hwmon || ""
                            }));
                            gpus.forEach(gpu => {
                                const vendor = (gpu.vendor || gpu.fullName || gpu.displayName || gpu.name || "").toLowerCase();
                                if (vendor.includes("nvidia") && !(gpu.temperature > 0)) needsNvidiaFallback = true;
                                if (!(gpu.temperature > 0)) needsHwmonFallback = true;
                            });
                            if (needsNvidiaFallback) root.refreshNvidiaGpu();
                            if (needsHwmonFallback) root.refreshGpuHwmon();
                        } else if (!isMonitorActive && !isQuickSettingsOpen) {
                            root.availableGpus = []; // Clear when not monitoring
                        } else {
                            root.refreshNvidiaGpu();
                            root.refreshGpuHwmon();
                        }
                    } catch (e) {

                    }
                });
            }
        }
        
        onExited: {
            dgopProcess.running = false;
            root.updatePending = false;
        }
    }

    Process {
        id: nvidiaGpuProcess
        command: ["bash", "-c", "command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,power.draw,driver_version --format=csv,noheader,nounits 2>/dev/null || true"]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim().split("\n")[0] || "";
                if (!line) return;

                const parts = line.split(",").map(part => part.trim());
                const name = parts[0] || "NVIDIA GPU";
                const temp = parseFloat(parts[1]);
                const usage = parseFloat(parts[2]);
                const power = parseFloat(parts[3]);
                const driver = parts[4] || "nvidia";

                if (!isNaN(temp) && temp > 0) {
                    root.mergeNvidiaGpu(name, temp, usage, power, driver);
                }
            }
        }

        onExited: {
            nvidiaGpuProcess.running = false;
        }
    }

    Process {
        id: gpuHwmonProcess
        command: ["bash", "-c", "for d in /sys/class/hwmon/hwmon*; do name=$(cat \"$d/name\" 2>/dev/null || true); lname=$(printf '%s' \"$name\" | tr '[:upper:]' '[:lower:]'); case \"$lname\" in *nvidia*|*nouveau*|*amdgpu*|*radeon*|*i915*|*xe*) ;; *) continue ;; esac; for input in \"$d\"/temp*_input; do [ -r \"$input\" ] || continue; base=${input%_input}; label=$(cat \"${base}_label\" 2>/dev/null || echo temp); value=$(cat \"$input\" 2>/dev/null || echo 0); [ \"$value\" -gt 0 ] 2>/dev/null || continue; printf '%s,%s,%s\\n' \"$name\" \"$label\" \"$value\"; break; done; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(line => line.trim() !== "");
                lines.forEach(line => {
                    const parts = line.split(",").map(part => part.trim());
                    const hwmonName = parts[0] || "GPU";
                    const label = parts[1] || "temp";
                    const temp = parseFloat(parts[2]) / 1000;
                    if (isNaN(temp) || temp <= 0) return;

                    const identity = hwmonName.toLowerCase();
                    let vendor = "GPU";
                    let displayName = `${hwmonName} ${label}`.trim();
                    if (identity.includes("nvidia") || identity.includes("nouveau")) {
                        vendor = "NVIDIA";
                        displayName = "NVIDIA GPU";
                    } else if (identity.includes("amdgpu") || identity.includes("radeon")) {
                        vendor = "AMD";
                        displayName = "AMD GPU";
                    } else if (identity.includes("i915") || identity === "xe") {
                        vendor = "Intel";
                        displayName = "Intel GPU";
                    }

                    root.mergeGpu(vendor, displayName, temp, NaN, NaN, "hwmon", hwmonName);
                });
            }
        }

        onExited: {
            gpuHwmonProcess.running = false;
        }
    }

    function parseSizeToMB(sizeStr) {
        if (!sizeStr) return 0;
        let val = parseFloat(sizeStr);
        if (isNaN(val)) return 0;
        let unit = sizeStr.toString().replace(/[0-9. ]/g, '').toUpperCase();
        if (unit.includes('T')) return val * 1024 * 1024;
        if (unit.includes('G')) return val * 1024;
        if (unit.includes('M')) return val;
        if (unit.includes('K')) return val / 1024;
        return Math.round(val / (1024 * 1024)); // Assume bytes
    }

    function prePopulateDisks() {
        let monitored = [{ "path": "/", "alias": "System" }];
        if (Config.options.system && Config.options.system.monitoredDisks) {
            monitored = Config.options.system.monitoredDisks;
        }
        root.diskStats = monitored.map(d => ({
            path: d.path || "/",
            label: (d.alias || d.path || "/").toUpperCase(),
            hasAlias: !!d.alias,
            usage: 0,
            total: 0,
            used: 0
        }));
    }

    Component.onCompleted: {
        root.prePopulateDisks();
        Qt.callLater(() => root.update());
    }

    Component.onDestruction: {
        dgopProcess.terminate();
    }
}
