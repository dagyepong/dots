pragma Singleton

import QtQuick 6.10
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    
    readonly property string configPath: "$HOME/.config/basedgoose.shell/config.json"
    
    property string wallpaperDirectory: "~/Pictures/walls"
    property string wallpaperDownloadDirectory: "~/Pictures/walls/downloaded"
    property string wallpaperResizeMode: "fit"  // no, crop, fit, stretch
    property string hyprlandMonitorsConfigPath: "~/.config/hypr/hyprland/monitors.conf"
    property bool initialized: false
    
    // Bar configuration
    property string barPosition: "top"  // top, bottom, left, right
    property var barModules: ({
        "left": ["shellmenu", "workspaces", "mediaplayer"],
        "center": ["systemstats"],
        "right": ["clock", "systemtray", "volume", "network", "bluetooth", "notifications", "power"]
    })
    
    Component.onCompleted: {
        loadConfig()
    }
    
    function loadConfig() {
        var configDir = "$HOME/.config/basedgoose.shell"
        
        createDirProcess.command = ["sh", "-c", "mkdir -p " + configDir]
        createDirProcess.running = true
    }
    
    Process {
        id: createDirProcess
        stdout: StdioCollector {
            onStreamFinished: {
                readConfigProcess.running = true
            }
        }
    }
    
    Process {
        id: readConfigProcess
        running: false
        command: ["sh", "-c", "cat " + root.configPath + " 2>/dev/null || echo '{}'"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var configText = text.trim()
                if (configText.length === 0) {
                    configText = "{}"
                }
                
                try {
                    var config = JSON.parse(configText)
                    if (config.wallpaperDirectory) {
                        root.wallpaperDirectory = config.wallpaperDirectory
                    }
                    if (config.wallpaperDownloadDirectory) {
                        root.wallpaperDownloadDirectory = config.wallpaperDownloadDirectory
                    }
                    if (config.hyprlandMonitorsConfigPath) {
                        root.hyprlandMonitorsConfigPath = config.hyprlandMonitorsConfigPath
                    }
                    if (config.wallpaperResizeMode) {
                        root.wallpaperResizeMode = config.wallpaperResizeMode
                    }
                    if (config.barPosition) {
                        root.barPosition = config.barPosition
                    }
                    if (config.barModules) {
                        root.barModules = config.barModules
                    }
                    // Save config if any defaults are missing
                    if (!config.wallpaperDirectory || !config.wallpaperDownloadDirectory || !config.wallpaperResizeMode || 
                        !config.hyprlandMonitorsConfigPath || !config.barPosition || !config.barModules) {
                        root.saveConfig()
                    }
                } catch (e) {
                    console.error("[ConfigService] Failed to parse config:", e)
                    root.saveConfig()
                }
                
                root.initialized = true
                console.log("[ConfigService] Initialized")
                console.log("[ConfigService] barPosition:", root.barPosition)
                console.log("[ConfigService] barModules:", JSON.stringify(root.barModules))
            }
        }
    }
    
    function saveConfig() {
        var config = {
            wallpaperDirectory: root.wallpaperDirectory,
            wallpaperDownloadDirectory: root.wallpaperDownloadDirectory,
            wallpaperResizeMode: root.wallpaperResizeMode,
            hyprlandMonitorsConfigPath: root.hyprlandMonitorsConfigPath,
            barPosition: root.barPosition,
            barModules: root.barModules
        }
        
        var configJson = JSON.stringify(config, null, 2)
        var escapedJson = configJson.replace(/%/g, "%%").replace(/'/g, "'\"'\"'")
        writeConfigProcess.command = ["sh", "-c", "printf '%s' '" + escapedJson + "' > " + root.configPath]
        writeConfigProcess.running = true
    }
    
    Process {
        id: writeConfigProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[ConfigService] Config saved to", root.configPath)
            }
        }
    }
    
    function setWallpaperDirectory(path) {
        root.wallpaperDirectory = path
        root.saveConfig()
    }

    function setWallpaperDownloadDirectory(path) {
        root.wallpaperDownloadDirectory = path
        root.saveConfig()
    }

    function setWallpaperResizeMode(mode) {
        root.wallpaperResizeMode = mode
        root.saveConfig()
    }
    
    function setHyprlandMonitorsConfigPath(path) {
        root.hyprlandMonitorsConfigPath = path
        root.saveConfig()
    }
    
    function setBarPosition(position) {
        root.barPosition = position
        root.saveConfig()
    }
    
    function setBarModules(modules) {
        root.barModules = modules
        root.saveConfig()
    }
}
