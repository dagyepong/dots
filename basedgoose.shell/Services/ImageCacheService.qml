pragma Singleton

import QtQuick 6.10
import Quickshell
import Quickshell.Io
import "../scripts/sha256.js" as Checksum

Singleton {
    id: root

    property bool imageMagickAvailable: false
    property bool initialized: false

    readonly property string baseDir: {
        var home = Quickshell.env("HOME")
        return home + "/.cache/basedgoose.shell/images/"
    }
    readonly property string wpThumbDir: baseDir + "wallpapers/thumbnails/"

    readonly property var basicImageFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp"]
    readonly property var extendedImageFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.webp", "*.avif"]
    readonly property var imageFilters: imageMagickAvailable ? extendedImageFilters : basicImageFilters

    property var pendingRequests: ({})
    property var processQueue: []
    property int runningProcesses: 0
    readonly property int maxConcurrentProcesses: 8

    signal cacheHit(string cacheKey, string cachedPath)
    signal cacheMiss(string cacheKey)
    signal processingComplete(string cacheKey, string cachedPath)
    signal processingFailed(string cacheKey, string error)

    Component.onCompleted: {
        createDirectories()
        checkMagickProcess.running = true
    }

    function createDirectories() {
        Quickshell.execDetached(["mkdir", "-p", wpThumbDir])
    }

    function getThumbnail(sourcePath, callback) {
        if (!sourcePath || sourcePath === "") {
            callback("", false)
            return
        }
        
        if (!imageMagickAvailable) {
            console.log("[ImageCache] ImageMagick not available, using original:", sourcePath)
            callback(sourcePath, false)
            return
        }

        getMtime(sourcePath, function(mtime) {
            const cacheKey = generateThumbnailKey(sourcePath, mtime)
            const cachedPath = wpThumbDir + cacheKey + ".png"

            processRequest(cacheKey, cachedPath, sourcePath, callback, function() {
                startThumbnailProcessing(sourcePath, cachedPath, cacheKey)
            })
        })
    }

    function generateThumbnailKey(sourcePath, mtime) {
        const keyString = sourcePath + "@384x384@" + (mtime || "unknown")
        return Checksum.sha256(keyString)
    }

    function processRequest(cacheKey, cachedPath, sourcePath, callback, processFn) {
        if (pendingRequests[cacheKey]) {
            pendingRequests[cacheKey].callbacks.push(callback)
            return
        }

        checkFileExists(cachedPath, function(exists) {
            if (exists) {
                callback(cachedPath, true)
                cacheHit(cacheKey, cachedPath)
                return
            }

            if (pendingRequests[cacheKey]) {
                pendingRequests[cacheKey].callbacks.push(callback)
                return
            }

            cacheMiss(cacheKey)
            pendingRequests[cacheKey] = {
                callbacks: [callback],
                sourcePath: sourcePath
            }

            processFn()
        })
    }

    function notifyCallbacks(cacheKey, path, success) {
        const request = pendingRequests[cacheKey]
        if (request) {
            request.callbacks.forEach(function(cb) {
                cb(path, success)
            })
            delete pendingRequests[cacheKey]
        }

        if (success) {
            processingComplete(cacheKey, path)
        } else {
            processingFailed(cacheKey, "Processing failed")
        }
    }

    function startThumbnailProcessing(sourcePath, outputPath, cacheKey) {
        const srcEsc = sourcePath.replace(/'/g, "'\\''")
        const dstEsc = outputPath.replace(/'/g, "'\\''")

        const command = `magick '${srcEsc}' -auto-orient -filter Lanczos -resize '384x384^' -gravity center -extent 384x384 -unsharp 0x0.5 '${dstEsc}'`
        
        queueProcess({
            command: command,
            cacheKey: cacheKey,
            outputPath: outputPath,
            sourcePath: sourcePath
        })
    }

    function queueProcess(request) {
        processQueue.push(request)
        processNextInQueue()
    }

    function processNextInQueue() {
        if (runningProcesses >= maxConcurrentProcesses || processQueue.length === 0) {
            return
        }

        const request = processQueue.shift()
        runningProcesses++

        const processString = `
            import QtQuick 6.10
            import Quickshell.Io
            Process {
                command: ["sh", "-c", ""]
                stdout: StdioCollector {}
                stderr: StdioCollector {}
            }
        `

        try {
            const processObj = Qt.createQmlObject(processString, root, "ImageProcess_" + request.cacheKey)
            processObj.command = ["sh", "-c", request.command]

            processObj.exited.connect(function(exitCode) {
                processObj.destroy()
                runningProcesses--

                if (exitCode !== 0) {
                    console.log("[ImageCache] Thumbnail generation failed for:", request.cacheKey)
                    notifyCallbacks(request.cacheKey, request.sourcePath, false)
                } else {
                    notifyCallbacks(request.cacheKey, request.outputPath, true)
                }

                processNextInQueue()
            })

            processObj.running = true
        } catch (e) {
            runningProcesses--
            notifyCallbacks(request.cacheKey, request.sourcePath, false)
            processNextInQueue()
        }
    }

    function getMtime(filePath, callback) {
        const processString = `
            import QtQuick 6.10
            import Quickshell.Io
            Process {
                command: ["stat", "-c", "%Y", ""]
                stdout: StdioCollector {}
                stderr: StdioCollector {}
            }
        `

        try {
            const processObj = Qt.createQmlObject(processString, root, "MtimeProcess")
            processObj.command = ["stat", "-c", "%Y", filePath]

            processObj.exited.connect(function(exitCode) {
                const mtime = exitCode === 0 ? processObj.stdout.text.trim() : ""
                processObj.destroy()
                callback(mtime)
            })

            processObj.running = true
        } catch (e) {
            callback("")
        }
    }

    function checkFileExists(filePath, callback) {
        const processString = `
            import QtQuick 6.10
            import Quickshell.Io
            Process {
                command: ["test", "-f", ""]
                stdout: StdioCollector {}
                stderr: StdioCollector {}
            }
        `

        try {
            const processObj = Qt.createQmlObject(processString, root, "FileExistsProcess")
            processObj.command = ["test", "-f", filePath]

            processObj.exited.connect(function(exitCode) {
                processObj.destroy()
                callback(exitCode === 0)
            })

            processObj.running = true
        } catch (e) {
            callback(false)
        }
    }

    function clearCache(callback) {
        console.log("[ImageCache] Clearing cache directory:", wpThumbDir)
        
        const processString = `
            import QtQuick 6.10
            import Quickshell.Io
            Process {
                command: ["sh", "-c", ""]
                stdout: StdioCollector {}
                stderr: StdioCollector {}
            }
        `

        try {
            const processObj = Qt.createQmlObject(processString, root, "ClearCacheProcess")
            processObj.command = ["sh", "-c", `rm -rf '${wpThumbDir}'* && echo "success"`]

            processObj.exited.connect(function(exitCode) {
                const success = exitCode === 0
                processObj.destroy()
                
                if (success) {
                    console.log("[ImageCache] Cache cleared successfully")
                } else {
                    console.log("[ImageCache] Failed to clear cache")
                }
                
                if (callback) {
                    callback(success)
                }
            })

            processObj.running = true
        } catch (e) {
            console.log("[ImageCache] Error clearing cache:", e)
            if (callback) {
                callback(false)
            }
        }
    }

    Process {
        id: checkMagickProcess
        command: ["sh", "-c", "command -v magick"]
        running: false

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: function(exitCode) {
            root.imageMagickAvailable = (exitCode === 0)
            root.initialized = true
            if (root.imageMagickAvailable) {
                console.log("[ImageCache] ImageMagick available")
            } else {
                console.log("[ImageCache] ImageMagick not found, thumbnails disabled")
            }
        }
    }
}
