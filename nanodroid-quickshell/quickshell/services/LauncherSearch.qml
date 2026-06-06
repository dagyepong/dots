pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/functions"

Singleton {
    id: root

    property string query: ""
    property var clipboardHistory: []
    property var usageData: ({})
    readonly property string clipboardThumbnailDir: "/tmp/nandoroid/clipboard"
    readonly property bool wantsClipboardHistory: {
        if (!Config.ready || !Config.options.search) return false;
        if (!GlobalStates.launcherOpen && !GlobalStates.spotlightOpen) return false;
        return query.trim().startsWith(Config.options.search.clipboardPrefix);
    }

    onClipboardHistoryChanged: {
        if (!clipboardHistory || clipboardHistory.length === 0) return;
        Quickshell.execDetached(["mkdir", "-p", root.clipboardThumbnailDir]);
        clipboardHistory.forEach(entry => {
            if (entry.isImage) {
                const thumbPath = root.clipboardThumbnailDir + "/" + entry.id + ".png";
                Quickshell.execDetached(["sh", "-c", 'test -f "$2" || cliphist decode "$1" > "$2"', "sh", entry.id, thumbPath]);
            }
        });
    }

    function closeAll() {
        GlobalStates.launcherOpen = false;
        GlobalStates.spotlightOpen = false;
    }

    readonly property var quickCommands: [
        { name: "Lock Screen", subtitle: "Session Action", id: "cmd-lock", icon: "lock", isPlugin: true, category: "Command", emoji: "", execute: () => { Session.lock(); root.closeAll(); } },
        { name: "Reboot System", subtitle: "Session Action", id: "cmd-reboot", icon: "restart_alt", isPlugin: true, category: "Command", emoji: "", execute: () => { Session.reboot(); root.closeAll(); } },
        { name: "Power Off", subtitle: "Session Action", id: "cmd-poweroff", icon: "power_settings_new", isPlugin: true, category: "Command", emoji: "", execute: () => { Session.poweroff(); root.closeAll(); } },
        { name: "Log Out", subtitle: "Exit Hyprland", id: "cmd-logout", icon: "logout", isPlugin: true, category: "Command", emoji: "", execute: () => { Session.logout(); root.closeAll(); } },
        { name: "Suspend", subtitle: "Session Action", id: "cmd-suspend", icon: "bedtime", isPlugin: true, category: "Command", emoji: "", execute: () => { Session.suspend(); root.closeAll(); } },
        { name: "Hibernate", subtitle: "Session Action", id: "cmd-hibernate", icon: "save", isPlugin: true, category: "Command", emoji: "", execute: () => { Session.hibernate(); root.closeAll(); } },
        { name: "Open Dashboard", subtitle: "Shell Interface", id: "cmd-dashboard", icon: "dashboard", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.dashboardOpen = true; root.closeAll(); } },
        { name: "Open Settings", subtitle: "Shell Interface", id: "cmd-settings", icon: "settings", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.settingsOpen = true; root.closeAll(); } },
        { name: "Display Settings", subtitle: "HyprMod Monitors", id: "cmd-display-settings", icon: "monitor", aliases: "display displays monitor monitors screen screens dual monitor external hdmi dp layout resolution refresh rate scale mirror rotate hyprmod", isPlugin: true, category: "Command", emoji: "", execute: () => { Quickshell.execDetached([Directories.home.replace("file://", "") + "/.local/bin/asura-display-manager"]); root.closeAll(); } },
        { name: "Shell Display Page", subtitle: "Nandoroid Settings", id: "cmd-shell-display-settings", icon: "display_settings", aliases: "shell display page nandoroid monitor settings internal", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.settingsPageIndex = 3; GlobalStates.settingsOpen = true; root.closeAll(); } },
        { name: "Shell System Monitor", subtitle: "Shell Interface", id: "cmd-monitor", icon: "monitoring", aliases: "overlay quick panel internal stats", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.activateSystemMonitor(); root.closeAll(); } },
        { name: "Workspace Overview", subtitle: "Shell Interface", id: "cmd-overview", icon: "grid_view", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.overviewOpen = true; root.closeAll(); } },
        { name: "Wallpaper & Style", subtitle: "Shell Interface", id: "cmd-wallpaper", icon: "palette", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.settingsPageIndex = 4; GlobalStates.settingsOpen = true; root.closeAll(); } },
        { name: "Bluetooth Settings", subtitle: "Shell Interface", id: "cmd-bluetooth", icon: "bluetooth", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.settingsPageIndex = 1; GlobalStates.settingsOpen = true; root.closeAll(); } },
        { name: "Network Settings", subtitle: "Shell Interface", id: "cmd-network", icon: "wifi", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.settingsPageIndex = 0; GlobalStates.settingsOpen = true; root.closeAll(); } },
        { name: "Quick Actions", subtitle: "Tools Menu", id: "cmd-tools", icon: "construction", isPlugin: true, category: "Command", emoji: "", execute: () => { GlobalStates.quickActionsOpen = true; root.closeAll(); } },
        { name: "Edit Config", subtitle: "Configuration File", id: "cmd-edit-config", icon: "edit_note", isPlugin: true, category: "Command", emoji: "", execute: () => { Quickshell.execDetached(["xdg-open", Directories.home.replace("file://", "") + "/.config/nandoroid/config.json"]); root.closeAll(); } },
        { name: "Clear All Clipboard", subtitle: "Clipboard Action", id: "cmd-clip-wipe", icon: "delete_sweep", isPlugin: true, category: "Command", emoji: "", execute: () => { Quickshell.execDetached(["cliphist", "wipe"]); root.closeAll(); } },
        { name: "Clear Old Clipboard", subtitle: "Keep 100 newest", id: "cmd-clip-clear-old", icon: "mop", isPlugin: true, category: "Command", emoji: "", execute: () => { Quickshell.execDetached(["sh", "-c", "cliphist list | tail -n +101 | cliphist delete"]); root.closeAll(); } },
        { name: "Clear New Clipboard", subtitle: "Clear last 10 entries", id: "cmd-clip-clear-new", icon: "history", isPlugin: true, category: "Command", emoji: "", execute: () => { Quickshell.execDetached(["sh", "-c", "cliphist list | head -n 10 | cliphist delete"]); root.closeAll(); } },
        { name: "Restart Shell", subtitle: "Maintenance (Fast)", id: "cmd-shell-restart", icon: "refresh", isPlugin: true, category: "Command", emoji: "", execute: () => { Quickshell.execDetached([Directories.home.replace("file://", "") + "/.config/quickshell/nandoroid/scripts/restartshell.sh"]); root.closeAll(); } },
        { name: "Restart Shell (Fix Tray)", subtitle: "Maintenance (Deep)", id: "cmd-shell-restart-fix", icon: "build", isPlugin: true, category: "Command", emoji: "", execute: () => { Quickshell.execDetached([Directories.home.replace("file://", "") + "/.config/quickshell/nandoroid/scripts/restart_fix.sh"]); root.closeAll(); } }
    ]

    readonly property var quickTools: [
        { name: "Screen Snip", subtitle: "Tool", id: "tool-snip", icon: "content_cut", isPlugin: true, category: "Tool", emoji: "", execute: () => { RegionService.screenshot(); root.closeAll(); } },
        { name: "Color Picker", subtitle: "Tool", id: "tool-picker", icon: "colorize", isPlugin: true, category: "Tool", emoji: "", execute: () => { Quickshell.execDetached(["hyprpicker", "-a"]); root.closeAll(); } },
        { name: "OCR", subtitle: "Tool", id: "tool-ocr", icon: "text_snippet", isPlugin: true, category: "Tool", emoji: "", execute: () => { RegionService.ocr(); root.closeAll(); } },
        { name: "QR Scanner", subtitle: "Tool", id: "tool-qr", icon: "qr_code_scanner", isPlugin: true, category: "Tool", emoji: "", execute: () => { RegionService.qrcode(); root.closeAll(); } },
        { name: "Lens Search", subtitle: "Tool", id: "tool-lens", icon: "image_search", isPlugin: true, category: "Tool", emoji: "", execute: () => { RegionService.search(); root.closeAll(); } },
        { name: "Screen Record", subtitle: "Tool", id: "tool-record", icon: "videocam", isPlugin: true, category: "Tool", emoji: "", execute: () => { RegionService.record(); root.closeAll(); } },
        { name: "Record w/ Sound", subtitle: "Tool", id: "tool-record-sound", icon: "mic", isPlugin: true, category: "Tool", emoji: "", execute: () => { RegionService.recordWithSound(); root.closeAll(); } },
        { name: "Record Fullscreen", subtitle: "Tool", id: "tool-record-full", icon: "fullscreen", isPlugin: true, category: "Tool", emoji: "", execute: () => { RegionService.recordFullscreenWithSound(); root.closeAll(); } }
    ]

    readonly property var smartActions: [
        { name: "System Monitor", subtitle: "Open btop in a window", id: "smart-system-monitor", icon: "monitoring", aliases: "system monitor monitors resource resources process processes task manager cpu gpu temp temperature heat btop htop", isPlugin: true, category: "Application", emoji: "", execute: () => { Quickshell.execDetached([Directories.home.replace("file://", "") + "/.local/bin/asura-system-monitor-app"]); root.closeAll(); } },
        { name: "Hypr System Info", subtitle: "Hyprland diagnostics", id: "smart-hyprsysteminfo", icon: "info", aliases: "hypr system info hyprsysteminfo diagnostics version copy gpu compositor wayland", isPlugin: true, category: "Application", emoji: "", execute: () => { Quickshell.execDetached(["bash", "-lc", "if command -v hyprsysteminfo >/dev/null 2>&1; then exec hyprsysteminfo; else notify-send 'Hypr System Info is not installed' 'Run ~/.local/bin/asura-install-hypr-info-mod-once.sh'; fi"]); root.closeAll(); } },
        { name: "HyprMod", subtitle: "Hyprland settings", id: "smart-hyprmod", icon: "tune", aliases: "hyprmod hyprland settings config gtk libadwaita wayland compositor monitor monitors display displays", isPlugin: true, category: "Application", emoji: "", execute: () => { Quickshell.execDetached(["bash", "-lc", "if command -v hyprmod >/dev/null 2>&1; then exec hyprmod; else notify-send 'HyprMod is not installed' 'Run ~/.local/bin/asura-install-hypr-info-mod-once.sh'; fi"]); root.closeAll(); } },
        { name: "HyprMod Display Manager", subtitle: "Monitors and screen layout", id: "smart-display-manager", icon: "display_settings", aliases: "display displays monitor monitors screen screens dual monitor external hdmi dp layout resolution refresh rate scale mirror rotate hyprmod nwg displays wdisplays kanshi wlr randr", isPlugin: true, category: "Application", emoji: "", execute: () => { Quickshell.execDetached([Directories.home.replace("file://", "") + "/.local/bin/asura-display-manager"]); root.closeAll(); } },
        { name: "Files", subtitle: "Open Home in Nautilus", id: "smart-file-manager", icon: "folder", aliases: "file files folder folders directory directories explorer manager files app nautilus gnome files home downloads documents browse thumbnails preview", isPlugin: true, category: "Application", emoji: "", execute: () => { Quickshell.execDetached([Directories.home.replace("file://", "") + "/.local/bin/asura-file-manager", Directories.home.replace("file://", "")]); root.closeAll(); } },
        { name: "Package Manager", subtitle: "Open Octopi", id: "smart-package-manager", icon: "deployed_code", aliases: "pacman package packages software app store install remove update upgrade repo repository aur octopi", isPlugin: true, category: "Application", emoji: "", execute: () => { Quickshell.execDetached(["sh", "-c", "command -v octopi >/dev/null 2>&1 && exec octopi"]); root.closeAll(); } },
        { name: "Archive Manager", subtitle: "Extract in Files", id: "smart-archive-manager", icon: "archive", aliases: "extract archive unzip zip rar 7z tar compress decompress ark file roller xarchiver", isPlugin: true, category: "Application", emoji: "", execute: () => { Quickshell.execDetached(["sh", "-c", "if command -v file-roller >/dev/null 2>&1; then exec file-roller; elif command -v nautilus >/dev/null 2>&1; then exec nautilus \"$HOME/Downloads\"; elif command -v ark >/dev/null 2>&1; then exec ark; else xdg-open \"$HOME/Downloads\"; fi"]); root.closeAll(); } }
    ]

    function aliasesForApp(app) {
        const id = (app.id || "").toLowerCase();
        const name = (app.name || "").toLowerCase();
        const aliases = [];

        if (id.includes("nautilus") || name.includes("files") || id.includes("cosmic-files") || id.includes("nemo") || id.includes("thunar") || id.includes("pcmanfm")) {
            aliases.push("file files folder folders directory directories explorer manager home downloads documents browse");
        }
        if (id.includes("octopi") || name.includes("octopi") || id.includes("pamac") || id.includes("discover")) {
            aliases.push("pacman package packages software app store install remove update upgrade repo repository aur");
        }
        if (id.includes("ark") || id.includes("file-roller") || id.includes("xarchiver") || id.includes("engrampa") || name.includes("archive")) {
            aliases.push("extract archive unzip zip rar 7z tar compress decompress");
        }
        if (id.includes("chromium") || id.includes("chrome") || id.includes("firefox") || name.includes("browser")) {
            aliases.push("browser web internet google search");
        }
        if (id.includes("kitty") || id.includes("terminal") || name.includes("terminal")) {
            aliases.push("terminal shell console command cli");
        }
        if (id.includes("bluetooth") || name.includes("bluetooth")) {
            aliases.push("bluetooth bt devices pair headphones");
        }
        if (id.includes("antigravity") || name.includes("antigravity")) {
            aliases.push("code ide editor google ai agent auth");
        }
        if (id.includes("btop") || id.includes("monitor") || name.includes("btop") || name.includes("monitor")) {
            aliases.push("system monitor monitors resource resources process processes task manager cpu gpu temp temperature heat performance");
        }
        if (id.includes("hyprsysteminfo") || name.includes("hypr system info")) {
            aliases.push("hypr system info hyprsysteminfo diagnostics version copy gpu compositor wayland");
        }
        if (id.includes("hyprmod") || name.includes("hyprmod")) {
            aliases.push("hyprmod hyprland settings config gtk libadwaita wayland compositor");
        }
        if (id.includes("display") || name.includes("display") || id.includes("wdisplay") || id.includes("nwg-displays")) {
            aliases.push("display displays monitor monitors screen screens dual monitor external hdmi dp layout resolution refresh rate scale mirror rotate");
        }

        return aliases.join(" ");
    }

    function searchBlob(item) {
        return [
            item.name || "",
            item.subtitle || "",
            item.id || "",
            item.category || "",
            item.aliases || ""
        ].join(" ").toLowerCase();
    }

    function searchScore(item, term) {
        const queryTerm = term.toLowerCase();
        const name = (item.name || "").toLowerCase();
        const id = (item.id || "").toLowerCase();
        const aliases = (item.aliases || "").toLowerCase();
        const blob = searchBlob(item);

        if (name === queryTerm) return 0;
        if (name.startsWith(queryTerm)) return 10;
        if (aliases.split(/\s+/).some(alias => alias === queryTerm)) return 15;
        if (aliases.split(/\s+/).some(alias => alias.startsWith(queryTerm))) return 18;
        if (name.includes(queryTerm)) return 25;
        if (id.includes(queryTerm)) return 35;
        if (aliases.includes(queryTerm)) return 45;
        if (blob.includes(queryTerm)) return 60;
        return 100;
    }

    Timer {
        id: fileSearchTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!Config.ready || !Config.options.search) return;
            const term = root.query.trim().slice(Config.options.search.filePrefix.length).trim();
            if (term.length > 0) {
                fileSearchProc.runSearch(term);
            } else {
                fileSearchProc.results = [];
                _triggerVal++;
            }
        }
    }

    Process {
        id: fileSearchProc
        running: false
        property var results: []
        command: ["fd", "-i", "-t", "f", "--max-results", "20", "", "/home"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0);
                fileSearchProc.results = lines.map(path => {
                    const parts = path.split("/");
                    const name = parts[parts.length - 1];
                    return {
                        name: name,
                        subtitle: path,
                        id: "file-" + path,
                        icon: "insert_drive_file",
                        isPlugin: true,
                        category: "File",
                        emoji: "",
                        execute: () => { 
                            Quickshell.execDetached(["xdg-open", path]); 
                            root.closeAll(); 
                        }
                    };
                });
                _triggerVal++;
            }
        }
        function runSearch(term) {
            running = false;
            const home = FileUtils.trimFileProtocol(Directories.home.toString());
            command = ["fd", "-i", "-t", "f", "--max-results", "20", term, home];
            running = true;
        }
    }

    onQueryChanged: {
        if (Config.ready && Config.options.search && query.trim().startsWith(Config.options.search.filePrefix)) {
            fileSearchTimer.restart();
        }
        if (wantsClipboardHistory) {
            cliphistProc.running = true;
        }
    }

    Process {
        id: cliphistProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.trim().length > 0);
                const newHistory = lines.slice(0, 50).map(line => {
                    const id = line.split("\t")[0];
                    const isImage = line.includes("[[ binary data");
                    return { id: id, raw: line, isImage: isImage };
                });
                
                if (JSON.stringify(newHistory) !== JSON.stringify(root.clipboardHistory)) {
                    root.clipboardHistory = newHistory;
                }
            }
        }
    }

    Timer {
        id: cliphistTimer
        interval: 2500
        running: root.wantsClipboardHistory
        repeat: true
        onTriggered: cliphistProc.running = true
    }

    FileView {
        id: usageFile
        path: Quickshell.shellPath("data/app_usage.json")
        watchChanges: true
        onLoaded: {
            try {
                root.usageData = JSON.parse(text());
            } catch(e) {
                root.usageData = {};
            }
            triggerUpdate();
        }
    }

    function recordExecution(appId) {
        if (!appId || !Config.options.search.enableUsageTracking) return;
        const currentCount = root.usageData[appId] || 0;
        root.usageData[appId] = currentCount + 1;
        const dataStr = JSON.stringify(root.usageData);
        const path = Quickshell.shellPath("data/app_usage.json");
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" > "$2"', "sh", dataStr, path]);
        triggerUpdate();
    }

    property var allApps: []
    property string selectedCategory: "All"
    
    Timer {
        id: debounceUpdateTimer
        interval: 500
        repeat: false
        onTriggered: root.updateAppModel()
    }

    function triggerUpdate() {
        debounceUpdateTimer.restart()
    }

    readonly property var categories: {
        const cats = new Set(["All"]);
        allApps.forEach(app => {
            if (app.category && app.category !== "Application" && app.category !== "Other") {
                cats.add(app.category);
            }
        });
        const sortedCats = Array.from(cats).sort((a, b) => {
            if (a === "All") return -1;
            if (b === "All") return 1;
            return a.localeCompare(b);
        });
        if (allApps.some(app => app.category === "Other")) sortedCats.push("Other");
        return sortedCats;
    }
    
    Timer {
        id: retryTimer
        interval: 2000
        running: allApps.length < 5
        repeat: true
        onTriggered: triggerUpdate()
    }
    
    Component.onCompleted: {
        triggerUpdate()
        usageFile.reload()
    }

    Connections {
        target: GlobalStates
        function onLauncherOpenChanged() {
            if (GlobalStates.launcherOpen) {
                if (allApps.length === 0) triggerUpdate();
            }
        }
        function onSpotlightOpenChanged() {
            if (GlobalStates.spotlightOpen) {
                if (allApps.length === 0) triggerUpdate();
            }
        }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { triggerUpdate() }
    }

    function updateAppModel() {
        const apps = Array.from(DesktopEntries.applications.values);
        if (apps.length === 0) return;
        
        const uniqueApps = new Map();
        for (const app of apps) {
            if (!uniqueApps.has(app.id)) uniqueApps.set(app.id, app);
        }
        
        const mapped = Array.from(uniqueApps.values()).map(app => {
            let category = "Other";
            
            if (app.categories && Array.isArray(app.categories)) {
                const cats = app.categories;
                if (cats.includes("Game")) category = "Games";
                else if (cats.includes("Development")) category = "Development";
                else if (cats.includes("Office")) category = "Office";
                else if (cats.includes("Network") || cats.includes("WebBrowser")) category = "Internet";
                else if (cats.includes("AudioVideo") || cats.includes("Audio") || cats.includes("Video")) category = "Multimedia";
                else if (cats.includes("Settings")) category = "Settings";
                else if (cats.includes("System")) category = "System";
                else if (cats.includes("Graphics")) category = "Graphics";
                else if (cats.includes("Utility")) category = "Utility";
            }
            
            if (category === "Other") {
                const id = app.id.toLowerCase();
                const name = app.name.toLowerCase();
                if (id.includes("game") || id.includes("steam") || id.includes("retroarch")) category = "Games";
                else if (id.includes("code") || id.includes("vsc") || id.includes("studio") || id.includes("devel") || id.includes("python") || id.includes("rust")) category = "Development";
                else if (id.includes("office") || id.includes("word") || id.includes("excel") || id.includes("calc") || id.includes("pdf") || id.includes("note")) category = "Office";
                else if (id.includes("browser") || id.includes("firefox") || id.includes("chrome") || id.includes("internet") || id.includes("mail")) category = "Internet";
                else if (id.includes("player") || id.includes("vlc") || id.includes("mpv") || id.includes("music") || id.includes("video") || id.includes("audio")) category = "Multimedia";
                else if (id.includes("setting") || id.includes("config") || id.includes("control") || id.includes("tweak")) category = "Settings";
                else if (id.includes("terminal") || id.includes("system") || id.includes("monitor") || id.includes("file") || id.includes("manage")) category = "System";
                else if (id.includes("graphic") || id.includes("draw") || id.includes("paint") || id.includes("photo") || id.includes("gimp") || id.includes("inkscape")) category = "Graphics";
            }

            return {
                name: app.name,
                icon: app.icon || "application-x-executable",
                id: app.id,
                execute: () => { recordExecution(app.id); app.execute(); },
                isPlugin: false,
                subtitle: app.id,
                category: category,
                aliases: root.aliasesForApp(app),
                emoji: ""
            };
        }).sort((a, b) => {
            const countA = root.usageData[a.id] || 0;
            const countB = root.usageData[b.id] || 0;
            if (countB !== countA) return countB - countA;
            return a.name.localeCompare(b.name);
        });
        
        allApps = mapped;
        _triggerVal++;

    }
    
    property int _triggerVal: 0

    Process {
        id: mathProc
        property string result: ""
        command: ["qalc", "-t"]
        stdout: StdioCollector {
            onStreamFinished: { mathProc.result = this.text.trim(); }
        }
        function calculate(expr) {
            running = false;
            command = ["qalc", "-t", expr];
            running = true;
        }
    }

    property var emojiList: []
    property bool emojisLoaded: false

    FileView {
        id: emojiFile
        path: Quickshell.shellPath("data/emojis.txt")
        onLoaded: {
            const lines = text().split("\n");
            const list = [];
            for (const line of lines) {
                const match = line.match(/^(\S+)\s+(.+)$/);
                if (match) list.push({ emoji: match[1], name: match[2] });
            }
            emojiList = list;
            emojisLoaded = true;
        }
    }

    readonly property bool isPluginSearch: {
        const stripped = query.trim();
        if (!Config.ready || !Config.options.search) return false;
        return [
            Config.options.search.mathPrefix,
            Config.options.search.webPrefix,
            Config.options.search.emojiPrefix,
            Config.options.search.clipboardPrefix,
            Config.options.search.filePrefix,
            Config.options.search.commandPrefix,
            Config.options.search.toolsPrefix
        ].some(p => stripped.startsWith(p));
    }

    readonly property var results: {
        const strippedQuery = query.trim();
        const isClipboard = strippedQuery.startsWith(Config.options.search.clipboardPrefix);
        if (isClipboard) clipboardHistory; 
        _triggerVal
        
        if (strippedQuery === "") {
            if (Config.ready && Config.options.search && Config.options.search.enableGrouping && selectedCategory !== "All") {
                return allApps.filter(app => app.category === selectedCategory);
            }
            return allApps;
        }

        const results = [];
        if (!Config.ready || !Config.options.search) return allApps;

        if (strippedQuery.startsWith(Config.options.search.mathPrefix)) {
            const mathExpr = strippedQuery.slice(Config.options.search.mathPrefix.length).trim();
            if (mathExpr.length > 0) {
                mathProc.calculate(mathExpr);
                results.push({
                    name: "Math Result",
                    subtitle: mathExpr + " = " + (mathProc.result || "..."),
                    id: "math-result", icon: "calculate", isPlugin: true, category: "Command", emoji: "",
                    execute: () => { Quickshell.clipboardText = mathProc.result; root.closeAll(); }
                });
            }
        } else if (strippedQuery.startsWith(Config.options.search.webPrefix)) {
            const webQuery = strippedQuery.slice(Config.options.search.webPrefix.length).trim();
            if (webQuery.length > 0) {
                results.push({
                    name: "Search Web", subtitle: webQuery, id: "web-search", icon: "public", isPlugin: true, category: "Command", emoji: "",
                    execute: () => { Qt.openUrlExternally("https://www.google.com/search?q=" + encodeURIComponent(webQuery)); root.closeAll(); }
                });
            }
        } else if (strippedQuery.startsWith(Config.options.search.emojiPrefix)) {
            const emojiQuery = strippedQuery.slice(Config.options.search.emojiPrefix.length).toLowerCase().trim();
            const emojiResults = [];
            for (const item of emojiList) {
                if (item.name.includes(emojiQuery) || emojiQuery === "") {
                    emojiResults.push({
                        name: item.name, subtitle: "Emoji", emoji: item.emoji, category: "Emoji", id: "emoji-" + item.name, icon: "face", isPlugin: true,
                        execute: () => { Quickshell.clipboardText = item.emoji; root.closeAll(); }
                    });
                }
            }
            emojiResults.sort((a, b) => {
                const aStarts = a.name.toLowerCase().startsWith(emojiQuery);
                const bStarts = b.name.toLowerCase().startsWith(emojiQuery);
                if (aStarts && !bStarts) return -1;
                if (!aStarts && bStarts) return 1;
                return a.name.localeCompare(b.name);
            });
            results.push(...emojiResults.slice(0, 50));
        } else if (strippedQuery.startsWith(Config.options.search.clipboardPrefix)) {
            const clipQuery = strippedQuery.slice(Config.options.search.clipboardPrefix.length).toLowerCase().trim();
            const clipResults = [];
            for (const entryObj of clipboardHistory) {
                const entry = entryObj.raw;
                const cleanName = entry.replace(/^\d+\t/, "").trim();
                if (cleanName.toLowerCase().includes(clipQuery) || clipQuery === "") {
                    const thumbPath = entryObj.isImage ? (root.clipboardThumbnailDir + "/" + entryObj.id + ".png") : "";
                    clipResults.push({
                        name: entryObj.isImage ? "Clipboard Image" : "Clipboard Entry",
                        subtitle: cleanName, rawValue: entry, id: "clip-" + entryObj.id, icon: entryObj.isImage ? "image" : "content_paste",
                        isPlugin: true, isImage: entryObj.isImage, imagePath: thumbPath, category: "Command", emoji: "",
                        execute: () => {
                            Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entryObj.id]);
                            root.closeAll();
                        }
                    });
                }
            }
            if (clipQuery !== "") {
                clipResults.sort((a, b) => {
                    const aStarts = a.subtitle.toLowerCase().startsWith(clipQuery);
                    const bStarts = b.subtitle.toLowerCase().startsWith(clipQuery);
                    if (aStarts && !bStarts) return -1;
                    if (!aStarts && bStarts) return 1;
                    
                    // If both start with query or both don't, maintain chronological order
                    // We use the numeric ID from cliphist (higher is newer)
                    const idA = parseInt(a.id.replace("clip-", ""));
                    const idB = parseInt(b.id.replace("clip-", ""));
                    return idB - idA;
                });
            }
            results.push(...clipResults.slice(0, 50));
        } else if (strippedQuery.startsWith(Config.options.search.commandPrefix)) {
            const cmdQuery = strippedQuery.slice(Config.options.search.commandPrefix.length).toLowerCase().trim();
            const cmdResults = [];
            for (const cmd of root.quickCommands) {
                if (cmd.name.toLowerCase().includes(cmdQuery) || cmd.id.toLowerCase().includes(cmdQuery) || cmdQuery === "") {
                    cmdResults.push(cmd);
                }
            }
            cmdResults.sort((a, b) => {
                const aStarts = a.name.toLowerCase().startsWith(cmdQuery);
                const bStarts = b.name.toLowerCase().startsWith(cmdQuery);
                if (aStarts && !bStarts) return -1;
                if (!aStarts && bStarts) return 1;
                return a.name.localeCompare(b.name);
            });
            results.push(...cmdResults);
        } else if (strippedQuery.startsWith(Config.options.search.toolsPrefix)) {
            const toolQuery = strippedQuery.slice(Config.options.search.toolsPrefix.length).toLowerCase().trim();
            const toolResults = [];
            for (const tool of root.quickTools) {
                if (tool.name.toLowerCase().includes(toolQuery) || tool.id.toLowerCase().includes(toolQuery) || toolQuery === "") {
                    toolResults.push(tool);
                }
            }
            toolResults.sort((a, b) => {
                const aStarts = a.name.toLowerCase().startsWith(toolQuery);
                const bStarts = b.name.toLowerCase().startsWith(toolQuery);
                if (aStarts && !bStarts) return -1;
                if (!aStarts && bStarts) return 1;
                return a.name.localeCompare(b.name);
            });
            results.push(...toolResults);
        } else if (strippedQuery.startsWith(Config.options.search.filePrefix)) {
            const fileQuery = strippedQuery.slice(Config.options.search.filePrefix.length).toLowerCase().trim();
            const fileResults = fileSearchProc.results.slice();
            fileResults.sort((a, b) => {
                const aStarts = a.name.toLowerCase().startsWith(fileQuery);
                const bStarts = b.name.toLowerCase().startsWith(fileQuery);
                if (aStarts && !bStarts) return -1;
                if (!aStarts && bStarts) return 1;
                return a.name.localeCompare(b.name);
            });
            results.push(...fileResults);
            if (fileSearchProc.results.length === 0 && strippedQuery.length > 1) {
                 results.push({
                    name: "Searching Files...", subtitle: "Please wait", id: "file-searching", icon: "search", isPlugin: true, category: "Command", emoji: "", execute: () => {}
                });
            }
        }

        if (!isPluginSearch) {
            const loweredQuery = strippedQuery.toLowerCase();
            const smartResults = root.smartActions.filter(action =>
                root.searchBlob(action).includes(loweredQuery)
            ).sort((a, b) => {
                const scoreA = root.searchScore(a, loweredQuery);
                const scoreB = root.searchScore(b, loweredQuery);
                if (scoreA !== scoreB) return scoreA - scoreB;
                return a.name.localeCompare(b.name);
            });

            const filteredApps = allApps.filter(app =>
                root.searchBlob(app).includes(loweredQuery)
            ).sort((a, b) => {
                const scoreA = root.searchScore(a, loweredQuery);
                const scoreB = root.searchScore(b, loweredQuery);
                if (scoreA !== scoreB) return scoreA - scoreB;

                const nameA = a.name.toLowerCase();
                const nameB = b.name.toLowerCase();
                const aStarts = nameA.startsWith(loweredQuery);
                const bStarts = nameB.startsWith(loweredQuery);

                if (aStarts && !bStarts) return -1;
                if (!aStarts && bStarts) return 1;

                if (Config.options.search.enableUsageTracking) {
                    const countA = root.usageData[a.id] || 0;
                    const countB = root.usageData[b.id] || 0;
                    if (countB !== countA) return countB - countA;
                }
                
                return nameA.localeCompare(nameB);
            });
            results.push(...smartResults);
            results.push(...filteredApps);
        }

        return (results.length > 0 || strippedQuery === "") ? results : allApps;
    }
}
