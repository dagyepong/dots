pragma Singleton

import QtQuick 6.10
import Quickshell
import Quickshell.Io
import "." as Services

Singleton {
    id: root

    signal wallpaperApplied()

    readonly property alias wallpaperList: listModel
    readonly property alias savedList: listModel
    readonly property alias downloadedList: downloadedListModel
    readonly property bool loading: loadingProcess.running
    readonly property bool savedLoading: loadingProcess.running
    readonly property bool downloadedLoading: downloadedLoadingProcess.running

    ListModel {
        id: listModel
    }

    ListModel {
        id: downloadedListModel
    }

    Process {
        id: loadingProcess
        running: false
        property string wallpaperDir: Services.ConfigService.initialized
            ? (Services.ConfigService.wallpaperDirectory.startsWith("~")
               ? Services.ConfigService.wallpaperDirectory.replace("~", "$HOME")
               : Services.ConfigService.wallpaperDirectory)
            : ""
        command: ["sh", "-c", "D=$(eval echo \"" + wallpaperDir.replace(/"/g, '\\"') + "\") && fd -e jpg -e jpeg -e png -e gif -e webp -e bmp -e avif -e jxl -t f --max-depth 3 . \"$D\""]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = text.trim()
                var lines = output.split('\n').filter(function(line) { return line.length > 0 })
                listModel.clear()

                for (var i = 0; i < lines.length; i++) {
                    var filePath = lines[i].trim()
                    if (filePath.length > 0) {
                        var fileName = filePath.substring(filePath.lastIndexOf("/") + 1)
                        listModel.append({
                            filePath: filePath,
                            fileName: fileName
                        })
                    }
                }
            }
        }
        
        stderr: StdioCollector { }
    }

    Process {
        id: downloadedLoadingProcess
        running: false
        property string downloadDir: Services.ConfigService.initialized
            ? (Services.ConfigService.wallpaperDownloadDirectory.startsWith("~")
               ? Services.ConfigService.wallpaperDownloadDirectory.replace("~", "$HOME")
               : Services.ConfigService.wallpaperDownloadDirectory)
            : ""
        command: ["sh", "-c", "D=$(eval echo \"" + downloadDir.replace(/"/g, '\\"') + "\") && fd -e jpg -e jpeg -e png -e gif -e webp -e bmp -e avif -e jxl -t f --max-depth 3 . \"$D\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = text.trim()
                var lines = output.split('\n').filter(function(line) { return line.length > 0 })
                downloadedListModel.clear()
                for (var i = 0; i < lines.length; i++) {
                    var filePath = lines[i].trim()
                    if (filePath.length > 0) {
                        var fileName = filePath.substring(filePath.lastIndexOf("/") + 1)
                        downloadedListModel.append({
                            filePath: filePath,
                            fileName: fileName
                        })
                    }
                }
            }
        }
        stderr: StdioCollector { }
    }

    Process {
        id: setWallpaperProcess
        running: false
        command: []
        stdout: StdioCollector { }
    }

    property var popupWindow: null
    
    Process {
        id: directoryDialogProcess
        running: false
        property int target: 0  // 0 = wallpaper, 1 = download
        command: ["sh", "-c", "zenity --file-selection --directory --title='Select Wallpaper Directory' 2>/dev/null || yad --file --directory --title='Select Wallpaper Directory' 2>/dev/null || echo ''"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.popupWindow) {
                    root.popupWindow.shouldShow = true
                }
                var selectedDir = text.trim()
                if (selectedDir.length > 0) {
                    if (directoryDialogProcess.target === 0) {
                        Services.ConfigService.setWallpaperDirectory(selectedDir)
                        root.refreshSaved()
                    } else {
                        Services.ConfigService.setWallpaperDownloadDirectory(selectedDir)
                        root.refreshDownloaded()
                    }
                }
            }
        }
        stderr: StdioCollector { }
    }

    Process {
        id: downloadDirDialogProcess
        running: false
        command: ["sh", "-c", "zenity --file-selection --directory --title='Select Download Directory' 2>/dev/null || yad --file --directory --title='Select Download Directory' 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.popupWindow) {
                    root.popupWindow.shouldShow = true
                }
                var selectedDir = text.trim()
                if (selectedDir.length > 0) {
                    Services.ConfigService.setWallpaperDownloadDirectory(selectedDir)
                    root.refreshDownloaded()
                }
            }
        }
        stderr: StdioCollector { }
    }

    Process {
        id: copyProcess
        running: false
    }

    Process {
        id: openProcess
        running: false
    }

    Process {
        id: deleteProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.popupWindow) {
                    root.popupWindow.shouldShow = true
                }
                root.refresh()
            }
        }
    }

    function refresh() {
        refreshSaved()
        refreshDownloaded()
    }

    function refreshSaved() {
        loadingProcess.running = false
        listModel.clear()
        loadingProcess.running = true
    }

    function refreshDownloaded() {
        downloadedLoadingProcess.running = false
        downloadedListModel.clear()
        downloadedLoadingProcess.running = true
    }

    function copyToSaved(sourcePath) {
        var dir = Services.ConfigService.wallpaperDirectory
        var dirForSh = dir.replace(/^~\//, "$HOME/").replace(/^~$/, "$HOME")
        var src = sourcePath.replace(/'/g, "'\"'\"'")
        var script = "D=$(eval echo \"" + dirForSh.replace(/"/g, '\\"') + "\"); mkdir -p \"$D\" && cp \"" + src + "\" \"$D/\" && echo copied"
        copyToSavedProcess.command = ["sh", "-c", script]
        copyToSavedProcess.running = true
    }

    Process {
        id: copyToSavedProcess
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().indexOf("copied") >= 0) {
                    root.refreshSaved()
                }
            }
        }
        stderr: StdioCollector { }
    }

    function setWallpaper(filePath) {
        var mode = Services.ConfigService.wallpaperResizeMode
        setWallpaperProcess.command = ["awww", "img", filePath, "--resize", mode, "--transition-fps", "60", "--transition-type", "outer"]
        setWallpaperProcess.running = true
        wallpaperApplied()
    }

    function openDirectoryDialog(which) {
        if (which === 1) {
            downloadDirDialogProcess.running = true
        } else {
            directoryDialogProcess.target = 0
            directoryDialogProcess.running = true
        }
    }
    
    function copyToClipboard(text) {
        var escapedText = text.replace(/'/g, "'\"'\"'")
        copyProcess.command = ["sh", "-c", "printf '%s' '" + escapedText + "' | wl-copy"]
        copyProcess.running = false
        copyProcess.running = true
    }

    function openFile(path) {
        var escaped = path.replace(/'/g, "'\"'\"'")
        openProcess.command = ["sh", "-c", "xdg-open '" + escaped + "' 2>/dev/null &"]
        openProcess.running = false
        openProcess.running = true
    }

    function deleteFile(path, name) {
        var ePath = path.replace(/'/g, "'\"'\"'")
        var eName = name.replace(/'/g, "'\"'\"'")
        deleteProcess.command = ["sh", "-c", "(zenity --question --text='Delete " + eName + "?' 2>/dev/null || yad --question --text='Delete " + eName + "?' 2>/dev/null) && rm -f '" + ePath + "' && echo deleted || echo canceled"]
        deleteProcess.running = false
        deleteProcess.running = true
    }
}
