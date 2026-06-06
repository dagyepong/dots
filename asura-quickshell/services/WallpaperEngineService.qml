pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property bool loading: false
    property string errorMessage: ""
    property string statusMessage: ""
    property bool isInstalled: false
    property bool hasRuntimeAssets: true
    property bool isApplying: false
    property bool isPaused: false
    property bool sortReversed: false
    property string searchQuery: ""
    property string selectedWallpaperId: ""
    property string activePreviewPath: ""
    property int screenshotVersion: 0

    readonly property bool isRunning: activeProcess.running
    readonly property bool active: (Config.ready && Config.options.appearance.background.liveWallpaperPath !== "") || isRunning
    readonly property string cacheDir: Directories.home.replace("file://", "") + "/.cache/nandoroid/live-wallpaper"
    property string screenshotPath: activePreviewPath !== "" ? activePreviewPath : cacheDir + "/active-preview.jpg"
    property int targetFps: Config.ready ? Config.options.wallpaperEngine.fps : 30
    property int volume: Config.ready ? Config.options.wallpaperEngine.volume : 15
    property bool silent: Config.ready ? Config.options.wallpaperEngine.silent : true
    property bool autoPause: Config.ready ? Config.options.wallpaperEngine.autoPause : true
    property string scaling: Config.ready ? Config.options.wallpaperEngine.scaling : "fill"

    readonly property ListModel currentProperties: ListModel { id: propsModel }
    readonly property ListModel allResults: ListModel { id: allResultsModel }
    readonly property ListModel results: ListModel { id: resultsModel }

    onSearchQueryChanged: updateFilteredResults()
    onSortReversedChanged: updateFilteredResults()

    function cleanPath(path) {
        let value = path ? path.toString() : "";
        if (value.startsWith("file://")) value = value.substring(7);
        return value;
    }

    function updateFilteredResults() {
        resultsModel.clear();
        const query = searchQuery.toLowerCase().trim();
        const temp = [];

        for (let i = 0; i < allResultsModel.count; i++) {
            const item = allResultsModel.get(i);
            const title = (item.title || "").toLowerCase();
            const id = (item.id || "").toLowerCase();
            if (query === "" || title.includes(query) || id.includes(query)) {
                const copy = {};
                for (let key in item) {
                    if (key !== "index") copy[key] = item[key];
                }
                temp.push(copy);
            }
        }

        temp.sort((a, b) => {
            const cmp = String(a.title || "").localeCompare(String(b.title || ""), undefined, { sensitivity: "base" });
            return sortReversed ? -cmp : cmp;
        });

        for (let item of temp) resultsModel.append(item);
    }

    function fetchProperties(folderPath, wallpaperId) {
        selectedWallpaperId = wallpaperId || "";
        propsModel.clear();
    }

    function updateProperty(key, value) {
        // Local video wallpapers do not expose scene-specific properties.
    }

    function resetProperties(folderPath) {
        propsModel.clear();
    }

    function refreshInstallState() {
        if (!checkInstallation.running) checkInstallation.running = true;
    }

    function fetch() {
        if (loading) return;
        errorMessage = "";
        loading = true;
        allResultsModel.clear();
        resultsModel.clear();
        scanProcess.running = true;
    }

    function apply(folderPath, previewPath = "") {
        const clean = cleanPath(folderPath);
        if (clean === "") return;

        if (!root.isInstalled) {
            root.errorMessage = "mpvpaper is required for live video wallpapers";
            Wallpapers.sendNotification("Live Wallpaper Error", root.errorMessage);
            return;
        }

        root.isApplying = true;
        stopInternal();

        const cleanPreview = cleanPath(previewPath);
        if (cleanPreview !== "") {
            root.activePreviewPath = cleanPreview;
            root.screenshotVersion = root.screenshotVersion + 1;
        }

        if (Config.ready) {
            Config.options.appearance.background.liveWallpaperPath = clean;
            if (cleanPreview !== "") Config.options.appearance.background.wallpaperPath = "file://" + cleanPreview;
        }

        applyInternal(clean);
    }

    function applyInternal(path) {
        const clean = cleanPath(path);
        if (clean === "" || !root.isInstalled) return;

        let output = "*";
        if (HyprlandData.monitors.length > 0) {
            const primary = HyprlandData.monitors.find(m => m.focused) || HyprlandData.monitors[0];
            output = primary.name || "*";
        }

        const mpvOptions = [
            "--loop-file=inf",
            "--really-quiet",
            "--hwdec=auto-safe",
            "--profile=sw-fast",
            "--video-sync=display-resample"
        ];
        if (root.silent || root.volume <= 0) {
            mpvOptions.push("--no-audio");
        } else {
            mpvOptions.push("--volume=" + Math.max(0, Math.min(100, root.volume)));
        }

        // Run via bash to kill hyprpaper and wait a brief moment for it to exit,
        // preventing the race condition where mpvpaper starts before hyprpaper is dead.
        activeProcess.command = [
            "bash",
            "-c",
            "pkill -KILL -x hyprpaper; sleep 0.15; exec mpvpaper -o \"" + mpvOptions.join(" ") + "\" \"" + output + "\" \"" + clean + "\""
        ];
        activeProcess.running = true;
        applyFinishTimer.restart();
    }

    function stop() {
        stopInternal();
        if (Config.ready) {
            Config.options.appearance.background.liveWallpaperPath = "";
            Config.options.gameModeState.previousLiveWallpaperPath = "";
        }
    }

    function stopInternal() {
        root.isApplying = false;
        applyFinishTimer.stop();
        if (activeProcess.running) activeProcess.running = false;
        Quickshell.execDetached(["pkill", "-CONT", "-x", "mpvpaper"]);
        Quickshell.execDetached(["pkill", "-KILL", "-x", "mpvpaper"]);
        root.isPaused = false;

        // Restart hyprpaper and restore the static wallpaper
        if (Config.ready && Config.options.appearance && Config.options.appearance.background) {
            const staticPath = Config.options.appearance.background.wallpaperPath;
            if (staticPath && staticPath !== "") {
                const cleanPath = staticPath.toString().startsWith("file://") ? staticPath.toString().substring(7) : staticPath.toString();
                if (cleanPath !== "") {
                    Wallpapers.writeHyprpaperConfig(cleanPath)

                    let restartCmd = `pgrep -x hyprpaper || hyprpaper &\n`
                    restartCmd += `sleep 0.2\n`
                    restartCmd += `hyprctl hyprpaper preload "${cleanPath}"\n`
                    if (HyprlandData.monitors && HyprlandData.monitors.length > 0) {
                        for (let i = 0; i < HyprlandData.monitors.length; i++) {
                            const mon = HyprlandData.monitors[i];
                            if (mon && mon.name) {
                                restartCmd += `hyprctl hyprpaper wallpaper "${mon.name},${cleanPath}"\n`
                            }
                        }
                    } else {
                        restartCmd += `hyprctl hyprpaper wallpaper ",${cleanPath}"\n`
                    }
                    restartCmd += `hyprctl hyprpaper unload all\n`
                    Quickshell.execDetached(["bash", "-c", restartCmd])
                }
            }
        }
    }

    function pause() {
        if (root.isRunning && !root.isPaused && !root.isApplying) {
            Quickshell.execDetached(["pkill", "-STOP", "-x", "mpvpaper"]);
            root.isPaused = true;
        }
    }

    function resume() {
        if (root.isRunning && root.isPaused) {
            Quickshell.execDetached(["pkill", "-CONT", "-x", "mpvpaper"]);
            root.isPaused = false;
        }
    }

    function updatePauseState() {
        if (root.isApplying || !root.autoPause || !root.isRunning || !HyprlandData.activeWorkspace) return;
        const currentWsId = HyprlandData.activeWorkspace.id;
        const shellClasses = ["Quickshell", "nandoroid-settings", "nandoroid-monitor", "waybar", "ags", "fuzzel", "mpvpaper"];
        const realWindows = HyprlandData.windowList.filter(win => {
            return win.workspace.id === currentWsId && !shellClasses.includes(win.class) && win.mapped && win.class !== "";
        });
        if (realWindows.length > 0) root.pause();
        else root.resume();
    }

    function checkInitialApply() {
        if (!Config.ready || !root.isInstalled) return;
        const lastPath = Config.options.appearance.background.liveWallpaperPath;
        if (lastPath && lastPath !== "") {
            root.findPreviewForPath(lastPath);
            root.applyInternal(lastPath);
        }
    }

    function findPreviewForPath(path) {
        const clean = cleanPath(path);
        for (let i = 0; i < allResultsModel.count; i++) {
            const item = allResultsModel.get(i);
            if (cleanPath(item.folder) === clean || cleanPath(item.path) === clean) {
                const preview = cleanPath(item.preview);
                if (preview !== "") {
                    root.activePreviewPath = preview;
                    root.screenshotVersion = root.screenshotVersion + 1;
                }
                return;
            }
        }
    }

    Timer {
        id: applyFinishTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.isApplying = false;
            if (root.activePreviewPath !== "") Wallpapers.generateColors(root.activePreviewPath);
            root.updatePauseState();
        }
    }

    Timer {
        id: pauseDebounceTimer
        interval: 500
        repeat: false
        onTriggered: root.updatePauseState()
    }

    Process {
        id: activeProcess
        onExited: (exitCode) => {
            root.isPaused = false;
            root.isApplying = false;
            if (exitCode !== 0 && Config.ready && Config.options.appearance.background.liveWallpaperPath !== "") {
                root.errorMessage = "mpvpaper exited with code " + exitCode;
            }
        }
    }

    Process {
        id: checkInstallation
        running: true
        command: ["python3", "-c", `
import json, shutil
mpvpaper = shutil.which("mpvpaper") or ""
ffmpeg = shutil.which("ffmpeg") or ""
status = "mpvpaper is ready" if mpvpaper else "Install mpvpaper to play local video wallpapers"
print(json.dumps({"mpvpaper": mpvpaper, "ffmpeg": ffmpeg, "status": status}))
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.isInstalled = data.mpvpaper !== "";
                    root.statusMessage = data.status || "";
                    root.errorMessage = root.isInstalled ? "" : root.statusMessage;
                    if (root.isInstalled) root.checkInitialApply();
                } catch (e) {
                    root.isInstalled = false;
                    root.statusMessage = "Unable to inspect mpvpaper installation";
                    root.errorMessage = root.statusMessage;
                }
            }
        }
    }

    Process {
        id: scanProcess
        command: ["python3", "-c", `
import hashlib, json, os, shutil, subprocess, sys

roots = []
for raw in sys.argv[1:]:
    if not raw:
        continue
    raw = raw.replace("file://", "")
    if os.path.isdir(raw) and raw not in roots:
        roots.append(raw)

exts = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v", ".gif"}
cache_dir = os.path.expanduser("~/.cache/nandoroid/live-wallpaper/thumbs")
os.makedirs(cache_dir, exist_ok=True)
ffmpeg = shutil.which("ffmpeg")

def preview_for(path):
    key = hashlib.sha1(path.encode("utf-8")).hexdigest() + ".jpg"
    out = os.path.join(cache_dir, key)
    need = not os.path.exists(out) or os.path.getmtime(out) < os.path.getmtime(path)
    if need and ffmpeg:
        try:
            subprocess.run([
                ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                "-ss", "00:00:01", "-i", path,
                "-frames:v", "1", "-vf", "scale=960:-1", out
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
        except Exception:
            pass
    return "file://" + out if os.path.exists(out) else ""

items = []
seen = set()
for root_dir in roots:
    for current, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".")][:16]
        if current[len(root_dir):].count(os.sep) > 2:
            dirs[:] = []
        for name in files:
            path = os.path.join(current, name)
            if path in seen:
                continue
            ext = os.path.splitext(name)[1].lower()
            if ext not in exts:
                continue
            seen.add(path)
            title = os.path.splitext(name)[0].replace("_", " ").replace("-", " ").strip() or name
            items.append({
                "id": hashlib.sha1(path.encode("utf-8")).hexdigest()[:12],
                "title": title,
                "folder": path,
                "path": path,
                "filePath": path,
                "fileName": name,
                "preview": preview_for(path),
                "type": "video"
            })

items.sort(key=lambda item: item["title"].lower())
print(json.dumps(items))
        `,
        Directories.home.replace("file://", "") + "/Pictures/Wallpapers",
        Directories.home.replace("file://", "") + "/Videos/Wallpapers",
        Directories.home.replace("file://", "") + "/Videos"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(this.text);
                    for (let item of data) root.allResults.append(item);
                    root.updateFilteredResults();
                    if (data.length === 0) root.errorMessage = "No local video wallpapers found";
                    if (Config.ready && Config.options.appearance.background.liveWallpaperPath !== "") {
                        root.findPreviewForPath(Config.options.appearance.background.liveWallpaperPath);
                    }
                } catch (e) {
                    root.errorMessage = "Unable to scan local video wallpapers";
                }
            }
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                root.refreshInstallState();
                root.fetch();
            }
        }
    }

    Connections {
        target: HyprlandData
        enabled: root.autoPause && root.isRunning
        function onWindowListChanged() { pauseDebounceTimer.restart(); }
        function onActiveWindowChanged() { pauseDebounceTimer.restart(); }
    }

    Connections {
        target: Session
        ignoreUnknownSignals: true
        function onLockedChanged() {
            if (Session.locked) root.pause();
            else pauseDebounceTimer.restart();
        }
    }

    Component.onCompleted: {
        root.refreshInstallState();
        root.fetch();
    }

    Component.onDestruction: root.stopInternal()
}
