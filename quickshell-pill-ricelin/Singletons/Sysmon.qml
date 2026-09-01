pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * System-vitals backend for the SYSTEM surface. Polling only runs while the
 * surface is open. GPU telemetry is modelled as a list so multi-GPU machines can
 * show every adapter that is visible locally, even when a vendor-specific stats
 * backend is unavailable.
 */
Singleton {
    id: root

    property bool open: false

    property int cpu: 0
    property int cpuTemp: -1

    property var gpus: []
    property bool hasGpu: false
    property string gpuVendor: "none"
    property string amdDev: ""
    property int gpu: 0
    property int gpuTemp: -1
    property bool hasVram: false
    property real vramUsedGb: 0
    property real vramTotalGb: 0

    property real memUsedGb: 0
    property real memTotalGb: 0
    property int memPct: 0
    property real swapUsedGb: 0

    property real netDown: 0
    property real netUp: 0

    property int diskPct: 0
    property string uptime: ""

    property bool detected: false
    property string tempPath: ""

    property real prevCpuTotal: 0
    property real prevCpuIdle: 0
    property real prevRx: 0
    property real prevTx: 0
    property real prevNetTime: 0
    property var prevXeCounters: ({})

    function primeAll() {
        if (!detected) {
            detectProc.running = true;
            return;
        }
        prevCpuTotal = 0;
        prevRx = 0;
        prevNetTime = 0;
        prevXeCounters = ({});
        fastProc.running = true;
        if (hasGpu)
            gpuProc.running = true;
        slowProc.running = true;
    }

    onOpenChanged: if (open) primeAll()

    function fmtUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var hh = h < 10 ? "0" + h : "" + h;
        var mm = m < 10 ? "0" + m : "" + m;
        return "UP " + d + "D " + hh + ":" + mm;
    }

    function cleanLabel(vendor, raw) {
        var label = (raw || "").replace(/\s+/g, " ").trim();
        if (vendor === "intel") {
            if (label.indexOf("Arc B580") >= 0)
                return "Arc B580";
            if (label.indexOf("Arc") >= 0) {
                var arc = label.match(/Arc [A-Za-z0-9 -]+/);
                if (arc)
                    return arc[0].replace(/\s+\[[^\]]+\].*$/, "").trim();
            }
            return "Intel GPU";
        }
        if (vendor === "nvidia") {
            if (label.indexOf("RTX 3090") >= 0)
                return "RTX 3090";
            var geforce = label.match(/\[GeForce ([^\]]+)\]/);
            if (geforce)
                return geforce[1];
            return label.replace(/^.*NVIDIA Corporation\s+/, "").replace(/\s+\[[^\]]+\].*$/, "").trim() || "NVIDIA GPU";
        }
        if (vendor === "amd")
            return label.replace(/^.*Advanced Micro Devices, Inc\. \[AMD\/ATI\]\s+/, "").replace(/\s+\[[^\]]+\].*$/, "").trim() || "AMD GPU";
        return label || "GPU";
    }

    function shortLabel(vendor, label) {
        var up = (label || "").toUpperCase();
        if (vendor === "intel" && up.indexOf("ARC") >= 0) {
            var arc = (label || "").match(/Arc\s+[A-Za-z0-9]+/i);
            return arc ? arc[0] : "Intel Arc";
        }
        if (up.indexOf("RTX 3090") >= 0)
            return "RTX 3090";
        if (up.indexOf("RTX") >= 0) {
            var rtx = up.match(/RTX\s+[0-9A-Z]+/);
            if (rtx)
                return rtx[0];
        }
        if (vendor === "nvidia")
            return "NVIDIA";
        if (vendor === "intel")
            return "INTEL";
        if (vendor === "amd")
            return "AMD";
        return "GPU";
    }

    function knownVramTotalGb(vendor, label, deviceId) {
        var l = (label || "").toUpperCase();
        var dev = (deviceId || "").toLowerCase();
        if (vendor === "intel" && (dev === "0xe20b" || l.indexOf("ARC B580") >= 0))
            return 12;
        if (vendor === "nvidia" && l.indexOf("RTX 3090") >= 0)
            return 24;
        return 0;
    }

    function emptyGpu(id, vendor, label, pci, devPath, deviceId) {
        var clean = cleanLabel(vendor, label);
        var knownVram = knownVramTotalGb(vendor, clean, deviceId);
        return {
            "id": id,
            "vendor": vendor,
            "label": clean,
            "shortLabel": shortLabel(vendor, clean),
            "pci": pci || "",
            "devPath": devPath || "",
            "deviceId": deviceId || "",
            "load": -1,
            "temp": -1,
            "vramTemp": -1,
            "hasVram": false,
            "vramUsedGb": 0,
            "vramTotalGb": knownVram,
            "knownVramTotalGb": knownVram,
            "status": vendor === "nvidia" ? "offline" : "sensor",
            "powerW": -1,
            "energyUj": -1,
            "energyTime": 0
        };
    }

    function cloneWith(base, patch) {
        var out = {};
        for (var k in base)
            out[k] = base[k];
        for (var p in patch)
            out[p] = patch[p];
        return out;
    }

    function gpuIdForPci(pci, vendor) {
        for (var i = 0; i < gpus.length; i++) {
            var g = gpus[i];
            if (g.vendor === vendor && g.pci === pci)
                return g.id;
        }
        return vendor + "0";
    }

    function gpuKnownVramTotal(id) {
        for (var i = 0; i < gpus.length; i++) {
            var g = gpus[i];
            if (g.id === id)
                return g.knownVramTotalGb > 0 ? g.knownVramTotalGb : g.vramTotalGb;
        }
        return 0;
    }

    function xeLoad(id, samples) {
        var oldByEngine = prevXeCounters[id] || {};
        var nextByEngine = {};
        var busy = 0;
        var anyDelta = false;

        for (var i = 0; i < samples.length; i++) {
            var s = samples[i];
            nextByEngine[s.engine] = {
                "cycles": s.cycles,
                "total": s.total,
                "capacity": s.capacity
            };

            var old = oldByEngine[s.engine];
            if (!old)
                continue;

            var dc = s.cycles - old.cycles;
            var dt = s.total - old.total;
            if (dc < 0 || dt <= 0)
                continue;

            var cap = s.capacity > 0 ? s.capacity : 1;
            busy += Math.max(0, Math.min(100, 100 * dc / (dt * cap)));
            anyDelta = true;
        }

        var nextAll = cloneWith(prevXeCounters, {});
        nextAll[id] = nextByEngine;
        prevXeCounters = nextAll;

        return anyDelta ? Math.max(0, Math.min(100, Math.round(busy))) : -1;
    }

    function syncLegacy() {
        hasGpu = gpus.length > 0;
        gpuVendor = hasGpu ? gpus[0].vendor : "none";
        amdDev = hasGpu && gpus[0].vendor === "amd" ? gpus[0].devPath : "";
        gpu = hasGpu && gpus[0].load >= 0 ? gpus[0].load : 0;
        gpuTemp = hasGpu ? gpus[0].temp : -1;

        var used = 0;
        var total = 0;
        var anyVram = false;
        for (var i = 0; i < gpus.length; i++) {
            var g = gpus[i];
            if (g.hasVram && g.vramTotalGb > 0) {
                anyVram = true;
                used += g.vramUsedGb;
                total += g.vramTotalGb;
            }
        }
        hasVram = anyVram;
        vramUsedGb = used;
        vramTotalGb = total;
    }

    function setDetectedGpus(next) {
        var merged = [];
        for (var i = 0; i < next.length; i++) {
            var incoming = next[i];
            var old = null;
            for (var j = 0; j < gpus.length; j++) {
                if (gpus[j].id === incoming.id) {
                    old = gpus[j];
                    break;
                }
            }
            merged.push(old ? cloneWith(incoming, {
                "load": old.load,
                "temp": old.temp,
                "vramTemp": old.vramTemp,
                "hasVram": old.hasVram,
                "vramUsedGb": old.vramUsedGb,
                "vramTotalGb": old.vramTotalGb,
                "status": old.status,
                "powerW": old.powerW,
                "energyUj": old.energyUj,
                "energyTime": old.energyTime
            }) : incoming);
        }
        gpus = merged;
        detected = true;
        syncLegacy();
    }

    function updateGpu(id, patch) {
        var next = gpus.slice();
        var idx = -1;
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                idx = i;
                break;
            }
        }

        var cur = idx >= 0 ? next[idx] : emptyGpu(id, "gpu", "GPU", "", "", "");
        if (patch.energyUj !== undefined && patch.energyUj >= 0) {
            var now = Date.now();
            if (cur.energyUj >= 0 && cur.energyTime > 0 && patch.energyUj >= cur.energyUj) {
                var dt = (now - cur.energyTime) / 1000;
                if (dt > 0)
                    patch.powerW = (patch.energyUj - cur.energyUj) / dt / 1000000;
            }
            patch.energyTime = now;
        }

        var merged = cloneWith(cur, patch);
        if (idx >= 0)
            next[idx] = merged;
        else
            next.push(merged);
        gpus = next;
        syncLegacy();
    }

    Component.onCompleted: detectProc.running = true

    Process {
        id: detectProc
        command: ["sh", "-c",
            "tp=''; for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = Tdie ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = 'Package id 0' ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = Tctl ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do [ -r \"$h/temp1_input\" ] && { tp=\"$h/temp1_input\"; break; }; done; "
            + "echo \"TEMP|$tp\"; "
            + "i=0; a=0; for d in /sys/class/drm/card*/device; do [ -r \"$d/vendor\" ] || continue; v=$(cat \"$d/vendor\" 2>/dev/null); case \"$v\" in 0x8086|0x1002) pci=$(basename \"$(readlink -f \"$d\")\"); dev=$(cat \"$d/device\" 2>/dev/null); label=$(lspci -D -s \"$pci\" 2>/dev/null | sed 's/^[^ ]* //'); [ -z \"$label\" ] && label=\"$v $dev\"; if [ \"$v\" = 0x1002 ]; then vendor=amd; id=\"amd${a}\"; a=$((a+1)); else vendor=intel; id=\"intel${i}\"; i=$((i+1)); fi; echo \"GPU|$id|$vendor|$pci|$label|$d|$dev\";; esac; done; "
            + "n=0; if command -v lspci >/dev/null 2>&1; then lspci -Dnn | while IFS= read -r line; do case \"$line\" in *NVIDIA*) case \"$line\" in *VGA*|*3D*|*Display*) pci=${line%% *}; label=$(printf '%s' \"$line\" | sed 's/^[^ ]* //'); echo \"GPU|nvidia${n}|nvidia|$pci|$label||\"; n=$((n+1));; esac;; esac; done; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var next = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.length === 0)
                        continue;
                    var p = line.split("|");
                    if (p[0] === "TEMP") {
                        root.tempPath = p.slice(1).join("|");
                    } else if (p[0] === "GPU" && p.length >= 5) {
                        var id = p[1];
                        var vendor = p[2];
                        var pci = p[3] || "";
                        var label = p[4] || "";
                        var path = p[5] || "";
                        var deviceId = p[6] || "";
                        next.push(root.emptyGpu(id, vendor, label, pci, path, deviceId));
                    }
                }
                root.setDetectedGpus(next);
                if (root.open)
                    root.primeAll();
            }
        }
    }

    Process {
        id: fastProc
        command: ["sh", "-c",
            "read -r _ a b c d e f g h _ < /proc/stat; echo \"CPU $((a+b+c+d+e+f+g+h)) $((d+e))\"; "
            + "awk '/^MemTotal:/{mt=$2}/^MemAvailable:/{ma=$2}/^SwapTotal:/{st=$2}/^SwapFree:/{sf=$2}END{print \"MEM\",mt,ma,st,sf}' /proc/meminfo; "
            + "awk 'NR>2{gsub(\":\",\" \");if($1!=\"lo\"){rx+=$2;tx+=$10}}END{print \"NET\",rx+0,tx+0}' /proc/net/dev; "
            + "if [ -n \"$1\" ] && [ -r \"$1\" ]; then echo \"TMP $(cat \"$1\")\"; else echo 'TMP -'; fi",
            "_", root.tempPath]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "CPU") {
                        var total = parseFloat(p[1]);
                        var idle = parseFloat(p[2]);
                        if (root.prevCpuTotal > 0) {
                            var dt = total - root.prevCpuTotal;
                            var di = idle - root.prevCpuIdle;
                            root.cpu = dt > 0 ? Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt))) : 0;
                        }
                        root.prevCpuTotal = total;
                        root.prevCpuIdle = idle;
                    } else if (p[0] === "MEM") {
                        var mt = parseFloat(p[1]);
                        var ma = parseFloat(p[2]);
                        var st = parseFloat(p[3]);
                        var sf = parseFloat(p[4]);
                        root.memTotalGb = mt / 1048576;
                        root.memUsedGb = (mt - ma) / 1048576;
                        root.memPct = mt > 0 ? Math.round(100 * (mt - ma) / mt) : 0;
                        root.swapUsedGb = (st - sf) / 1048576;
                    } else if (p[0] === "NET") {
                        var rx = parseFloat(p[1]);
                        var tx = parseFloat(p[2]);
                        var now = Date.now();
                        var dtNet = (now - root.prevNetTime) / 1000;
                        if (root.prevNetTime > 0 && dtNet > 0) {
                            root.netDown = Math.max(0, (rx - root.prevRx) / dtNet / 1048576);
                            root.netUp = Math.max(0, (tx - root.prevTx) / dtNet / 1048576);
                        }
                        root.prevRx = rx;
                        root.prevTx = tx;
                        root.prevNetTime = now;
                    } else if (p[0] === "TMP") {
                        root.cpuTemp = p[1] === "-" ? -1 : Math.round(parseFloat(p[1]) / 1000);
                    }
                }
            }
        }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c",
            "for h in /sys/class/hwmon/hwmon*; do [ -r \"$h/name\" ] || continue; [ \"$(cat \"$h/name\")\" = xe ] || continue; pkg=''; vram=''; vram_sum=0; vram_n=0; energy=''; for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; lab=$(cat \"$l\"); input=\"${l%_label}_input\"; val=$(cat \"$input\" 2>/dev/null); [ \"$lab\" = pkg ] && pkg=\"$val\"; [ \"$lab\" = vram ] && vram=\"$val\"; case \"$lab\" in vram_ch_*) [ -n \"$val\" ] && { vram_sum=$((vram_sum + val)); vram_n=$((vram_n + 1)); };; esac; done; [ \"$vram_n\" -gt 0 ] && vram=$((vram_sum / vram_n)); [ -z \"$pkg\" ] && [ -r \"$h/temp1_input\" ] && pkg=$(cat \"$h/temp1_input\" 2>/dev/null); [ -r \"$h/energy1_input\" ] && energy=$(cat \"$h/energy1_input\" 2>/dev/null); pkgc=-1; vramc=-1; [ -n \"$pkg\" ] && pkgc=$((pkg/1000)); [ -n \"$vram\" ] && vramc=$((vram/1000)); echo \"GPUSTAT|intel0|-1|$pkgc|0|0|sensor|$vramc|${energy:--1}\"; break; done; "
            + "for p in /proc/[0-9]*/fdinfo/*; do [ -r \"$p\" ] || continue; echo FILE; cat \"$p\" 2>/dev/null; done | awk 'function unit_bytes(v,u){if(u==\"KiB\")return v*1024;if(u==\"MiB\")return v*1048576;if(u==\"GiB\")return v*1073741824;return v} function flush(e,key){if(driver==\"xe\"&&pdev!=\"\"){key=pdev \"|\" client;if(!(key in seen)){seen[key]=1;for(e in cyc){cycles[pdev SUBSEP e]+=cyc[e];totals[pdev SUBSEP e]=tot[e];caps[pdev SUBSEP e]=cap[e]>0?cap[e]:1}vram[pdev]+=residentVram>0?residentVram:totalVram}}delete cyc;delete tot;delete cap;driver=\"\";pdev=\"\";client=\"\";totalVram=0;residentVram=0} /^FILE$/{flush();next} /^drm-driver:/{driver=$2} /^drm-client-id:/{client=$2} /^drm-pdev:/{pdev=$2} /^drm-cycles-/{e=$1;sub(/^drm-cycles-/,\"\",e);sub(/:$/,\"\",e);cyc[e]=$2} /^drm-total-cycles-/{e=$1;sub(/^drm-total-cycles-/,\"\",e);sub(/:$/,\"\",e);tot[e]=$2} /^drm-engine-capacity-/{e=$1;sub(/^drm-engine-capacity-/,\"\",e);sub(/:$/,\"\",e);cap[e]=$2} /^drm-resident-vram0:/{residentVram=unit_bytes($2,$3)} /^drm-total-vram0:/{totalVram=unit_bytes($2,$3)} END{flush();for(k in cycles){split(k,a,SUBSEP);print \"XECYCLE|\" a[1] \"|\" a[2] \"|\" cycles[k] \"|\" totals[k] \"|\" caps[k]}for(p in vram)printf \"XEVRAM|%s|%.3f\\n\",p,vram[p]/1073741824}'; "
            + "a=0; for d in /sys/class/drm/card*/device; do [ -r \"$d/vendor\" ] || continue; [ \"$(cat \"$d/vendor\" 2>/dev/null)\" = 0x1002 ] || continue; [ -r \"$d/gpu_busy_percent\" ] || continue; busy=$(cat \"$d/gpu_busy_percent\" 2>/dev/null); temp=$(cat \"$d\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); vu=$(cat \"$d/mem_info_vram_used\" 2>/dev/null); vt=$(cat \"$d/mem_info_vram_total\" 2>/dev/null); tempc=-1; [ -n \"$temp\" ] && tempc=$((temp/1000)); vug=$(awk -v b=\"${vu:-0}\" 'BEGIN{printf \"%.3f\", b/1073741824}'); vtg=$(awk -v b=\"${vt:-0}\" 'BEGIN{printf \"%.3f\", b/1073741824}'); echo \"GPUSTAT|amd${a}|${busy:--1}|$tempc|$vug|$vtg|ok|-1|-1\"; a=$((a+1)); done; "
            + "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then nvidia-smi --query-gpu=index,utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F', *' '{printf \"GPUSTAT|nvidia%s|%s|%s|%.3f|%.3f|ok|-1|-1\\n\",$1,$2,$3,$4/1024,$5/1024}'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var patches = {};
                var xeSamples = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p[0] === "GPUSTAT" && p.length >= 7) {
                        var id = p[1];
                        var load = parseFloat(p[2]);
                        var temp = parseFloat(p[3]);
                        var used = parseFloat(p[4]);
                        var total = parseFloat(p[5]);
                        var status = p[6] || "";
                        var vramTemp = p.length > 7 ? parseFloat(p[7]) : -1;
                        var energy = p.length > 8 ? parseFloat(p[8]) : -1;
                        var patch = patches[id] || {};
                        patch.load = isNaN(load) ? -1 : Math.max(-1, Math.min(100, Math.round(load)));
                        patch.temp = isNaN(temp) ? -1 : Math.round(temp);
                        patch.status = status.length > 0 ? status : "ok";
                        if (!isNaN(vramTemp))
                            patch.vramTemp = Math.round(vramTemp);
                        if (!isNaN(used) && !isNaN(total) && total > 0) {
                            patch.hasVram = true;
                            patch.vramUsedGb = used;
                            patch.vramTotalGb = total;
                        }
                        if (!isNaN(energy) && energy >= 0)
                            patch.energyUj = energy;
                        patches[id] = patch;
                    } else if (p[0] === "XECYCLE" && p.length >= 6) {
                        var pci = p[1];
                        var xeId = root.gpuIdForPci(pci, "intel");
                        if (!xeSamples[xeId])
                            xeSamples[xeId] = [];
                        xeSamples[xeId].push({
                            "engine": p[2],
                            "cycles": parseFloat(p[3]) || 0,
                            "total": parseFloat(p[4]) || 0,
                            "capacity": parseFloat(p[5]) || 1
                        });
                    } else if (p[0] === "XEVRAM" && p.length >= 3) {
                        var vramId = root.gpuIdForPci(p[1], "intel");
                        var vramPatch = patches[vramId] || {};
                        var vramUsed = parseFloat(p[2]);
                        var vramTotal = root.gpuKnownVramTotal(vramId);
                        if (!isNaN(vramUsed) && vramTotal > 0) {
                            vramPatch.hasVram = true;
                            vramPatch.vramUsedGb = vramUsed;
                            vramPatch.vramTotalGb = vramTotal;
                            patches[vramId] = vramPatch;
                        }
                    }
                }

                for (var sampleId in xeSamples) {
                    var pct = root.xeLoad(sampleId, xeSamples[sampleId]);
                    var xePatch = patches[sampleId] || {};
                    if (pct >= 0) {
                        xePatch.load = pct;
                        xePatch.status = "ok";
                    }
                    patches[sampleId] = xePatch;
                }

                for (var patchId in patches)
                    root.updateGpu(patchId, patches[patchId]);
            }
        }
    }

    Process {
        id: slowProc
        command: ["sh", "-c",
            "df -P / | awk 'NR==2{gsub(\"%\",\"\",$5);print \"DISK \"$5}'; awk '{print \"UP \"int($1)}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "DISK")
                        root.diskPct = parseInt(p[1], 10) || 0;
                    else if (p[0] === "UP")
                        root.uptime = root.fmtUptime(parseInt(p[1], 10) || 0);
                }
            }
        }
    }

    Timer {
        interval: 500
        running: root.open
        repeat: true
        onTriggered: if (!fastProc.running) fastProc.running = true
    }

    Timer {
        interval: 1000
        running: root.open && root.hasGpu
        repeat: true
        onTriggered: if (!gpuProc.running) gpuProc.running = true
    }

    Timer {
        interval: 5000
        running: root.open
        repeat: true
        onTriggered: if (!slowProc.running) slowProc.running = true
    }
}
