import QtQuick
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../../core/functions" as Functions

Process {
    id: screenshotProc
    running: true
    property string screenshotDir: Directories.screenshotTemp
    required property ShellScreen screen
    property string screenshotPath: `${screenshotDir}/image-${screen.name}`
    command: [Directories.home.replace("file://", "") + "/.local/bin/hyprcapture", "output", screen.name, "--path", screenshotPath]
}
