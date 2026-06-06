pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    
    readonly property string hyprcaptureCommand: Directories.home.replace("file://", "") + "/.local/bin/hyprcapture"

    function screenshot() { Quickshell.execDetached([hyprcaptureCommand, "open", "region"]) }
    function search() { Quickshell.execDetached(["qs", "-c", "nandoroid", "ipc", "call", "region", "search"]) }
    function ocr() { Quickshell.execDetached(["qs", "-c", "nandoroid", "ipc", "call", "region", "ocr"]) }
    function record() { Quickshell.execDetached([hyprcaptureCommand, "record", "region"]) }
    function recordWithSound() { Quickshell.execDetached([hyprcaptureCommand, "record", "region"]) }
    function recordFullscreenWithSound() { Quickshell.execDetached([hyprcaptureCommand, "record", "fullscreen"]) }
    function qrcode() { Quickshell.execDetached(["qs", "-c", "nandoroid", "ipc", "call", "region", "qrcode"]) }
}
