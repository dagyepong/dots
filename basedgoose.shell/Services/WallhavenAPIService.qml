pragma Singleton

import QtQuick 6.10
import Quickshell
import Quickshell.Io
import "." as Services

Singleton {
    id: root

    property int lastPage: 1
    property string seed: ""
    property bool loadedOnce: false

    readonly property alias wallhavenList: listModel
    readonly property bool running: apiProcess.running
    readonly property bool downloadRunning: downloadProcess.running

    ListModel {
        id: listModel
    }

    Process {
        id: apiProcess
        running: false
        command: ["sh", "-c", "echo '{}'"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loadedOnce = true
                listModel.clear()
                try {
                    var json = JSON.parse(text.trim())
                    if (json.data && Array.isArray(json.data)) {
                        for (var i = 0; i < json.data.length; i++) {
                            var w = json.data[i]
                            listModel.append({
                                id: w.id,
                                thumbUrl: w.thumbs && w.thumbs.large ? w.thumbs.large : "",
                                fullUrl: w.path || "",
                                resolution: w.resolution || ""
                            })
                        }
                        if (json.meta) {
                            root.lastPage = Math.max(1, json.meta.last_page || 1)
                            if (json.meta.seed)
                                root.seed = json.meta.seed
                        }
                    }
                } catch (e) {
                    console.error("[WallhavenAPIService] API parse error:", e)
                }
            }
        }
    }

    Process {
        id: downloadProcess
        running: false
        command: ["sh", "-c", "echo"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim()
                if (out.length > 0) {
                    if (out.indexOf("SAVED:") === 0) {
                        Services.WallpaperService.refreshSaved()
                    } else {
                        Services.WallpaperService.setWallpaper(out)
                    }
                }
            }
        }
    }

    function buildUrl(sorting, page, topRange, seedParam, query) {
        var url = "https://wallhaven.cc/api/v1/search?purity=100&page=" + page + "&sorting=" + sorting
        if (sorting === "toplist")
            url += "&topRange=" + topRange + "&order=desc"
        else if (sorting === "hot" || sorting === "date_added")
            url += "&order=desc"
        if (sorting === "random" && page > 1 && seedParam)
            url += "&seed=" + seedParam
        if (query && query.length > 0)
            url += "&q=" + encodeURIComponent(query)
        return url
    }

    function refresh(sorting, page, topRange, seedParam, query) {
        var url = buildUrl(sorting, page, topRange, seedParam, query)
        apiProcess.command = ["sh", "-c", "curl -s \"" + url.replace(/"/g, '\\"') + "\""]
        apiProcess.running = true
    }

    function downloadAndSet(whId, fullUrl) {
        if (downloadProcess.running)
            return
        if (!fullUrl || fullUrl.length === 0)
            return
        var dir = Services.ConfigService.wallpaperDownloadDirectory
        runDownload(whId, fullUrl, dir, true)
    }

    function downloadToSaved(whId, fullUrl) {
        if (downloadProcess.running)
            return
        if (!fullUrl || fullUrl.length === 0)
            return
        var dir = Services.ConfigService.wallpaperDirectory
        runDownload(whId, fullUrl, dir, false)
    }

    function runDownload(whId, fullUrl, targetDir, thenSet) {
        var url = fullUrl
        if (url.indexOf("/full/") === -1 && url.indexOf("w.wallhaven.cc/") !== -1) {
            url = url.replace(/w\.wallhaven\.cc\/(?!full)/, "w.wallhaven.cc/full/")
        }
        var ext = "jpg"
        var parts = fullUrl.split('.')
        if (parts.length > 1) {
            var last = parts[parts.length - 1].split('?')[0]
            if (last)
                ext = last.toLowerCase()
        }
        var dirForSh = targetDir.replace(/"/g, '\\"')
        var echoPrefix = thenSet ? "" : "SAVED:"
        var script = "D=$(eval echo \"" + dirForSh + "\"); mkdir -p \"$D\" && curl -sfL -o \"$D/wallhaven-$1.$2\" \"$3\" && echo \"" + echoPrefix + "$D/wallhaven-$1.$2\""
        downloadProcess.command = ["sh", "-c", script, "_", whId, ext, url]
        downloadProcess.running = true
    }
}
